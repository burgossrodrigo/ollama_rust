import { useState, useCallback, useEffect } from 'react';
import { IconButton } from '@mui/material';
import MenuIcon from '@mui/icons-material/Menu';
import AddIcon from '@mui/icons-material/Add';
import { Sidebar, ChatWindow, InputBar } from './components';
import { AppLayout, MainArea, MobileHeader, MobileTitle, Backdrop, CapacityBanner } from './components/style';
import type { Conversation, Message } from './types';

export default function App() {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [isStreaming, setIsStreaming] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [atCapacity, setAtCapacity] = useState(false);

  useEffect(() => {
    const check = async () => {
      try {
        const res = await fetch('/status');
        if (!res.ok) return;
        const data = await res.json() as { available: number };
        setAtCapacity(data.available === 0);
      } catch { /* ignore network errors */ }
    };
    check();
    const id = setInterval(check, 5000);
    return () => clearInterval(id);
  }, []);

  const activeConversation = conversations.find(c => c.id === activeId) ?? null;

  const handleNewChat = useCallback(() => {
    setActiveId(null);
    setSidebarOpen(false);
  }, []);

  const handleSelect = useCallback((id: string) => {
    setActiveId(id);
    setSidebarOpen(false);
  }, []);

  const handleSend = useCallback(async (text: string) => {
    if (isStreaming) return;

    let convId = activeId;
    if (!convId) {
      convId = crypto.randomUUID();
      const newConv: Conversation = { id: convId, title: text.slice(0, 42), messages: [] };
      setConversations(prev => [newConv, ...prev]);
      setActiveId(convId);
    }

    const userMsg: Message = { id: crypto.randomUUID(), role: 'user', content: text };
    const assistantId = crypto.randomUUID();
    const assistantMsg: Message = { id: assistantId, role: 'assistant', content: '', streaming: true };

    setConversations(prev =>
      prev.map(c => c.id === convId
        ? { ...c, messages: [...c.messages, userMsg, assistantMsg] }
        : c)
    );

    setIsStreaming(true);

    try {
      const res = await fetch('/prompt', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: text }),
      });

      if (res.status === 503) {
        setAtCapacity(true);
        throw new Error('at_capacity');
      }
      if (!res.ok || !res.body) throw new Error(`HTTP ${res.status}`);

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      outer: while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() ?? '';

        for (const line of lines) {
          if (!line.startsWith('data: ')) continue;
          const data = line.slice(6).trim();
          if (data === '[DONE]') break outer;
          try {
            const json = JSON.parse(data) as { response?: string; thinking?: string };
            if (json.thinking && !json.response) {
              setConversations(prev =>
                prev.map(c => c.id === convId
                  ? {
                      ...c,
                      messages: c.messages.map(m =>
                        m.id === assistantId ? { ...m, thinking: true } : m
                      ),
                    }
                  : c)
              );
            }
            if (json.response) {
              setConversations(prev =>
                prev.map(c => c.id === convId
                  ? {
                      ...c,
                      messages: c.messages.map(m =>
                        m.id === assistantId
                          ? { ...m, thinking: false, content: m.content + json.response }
                          : m
                      ),
                    }
                  : c)
              );
            }
          } catch { /* malformed JSON chunk — skip */ }
        }
      }
    } catch (e) {
      const isCapacity = e instanceof Error && e.message === 'at_capacity';
      if (!isCapacity) {
        setConversations(prev =>
          prev.map(c => c.id === convId
            ? {
                ...c,
                messages: c.messages.map(m =>
                  m.id === assistantId
                    ? { ...m, content: 'Error: could not reach the API.' }
                    : m
                ),
              }
            : c)
        );
      }
    } finally {
      setConversations(prev =>
        prev.map(c => c.id === convId
          ? {
              ...c,
              messages: c.messages.map(m =>
                m.id === assistantId ? { ...m, streaming: false } : m
              ),
            }
          : c)
      );
      setIsStreaming(false);
    }
  }, [activeId, isStreaming]);

  return (
    <AppLayout>
      <Backdrop $visible={sidebarOpen} onClick={() => setSidebarOpen(false)} />
      <Sidebar
        conversations={conversations}
        activeId={activeId}
        onSelect={handleSelect}
        onNewChat={handleNewChat}
        isOpen={sidebarOpen}
      />
      <MainArea>
        <MobileHeader>
          <IconButton size="small" onClick={() => setSidebarOpen(o => !o)} sx={{ color: '#ececec' }}>
            <MenuIcon />
          </IconButton>
          <MobileTitle>Ollama Chat</MobileTitle>
          <IconButton size="small" onClick={handleNewChat} sx={{ color: '#ececec' }}>
            <AddIcon />
          </IconButton>
        </MobileHeader>
        <ChatWindow conversation={activeConversation} />
        {atCapacity && (
          <CapacityBanner>⚡ Operando na capacidade máxima — tente novamente em instantes.</CapacityBanner>
        )}
        <InputBar onSend={handleSend} disabled={isStreaming || atCapacity} />
      </MainArea>
    </AppLayout>
  );
}
