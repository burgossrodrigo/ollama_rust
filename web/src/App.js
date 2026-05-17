import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useState, useCallback } from 'react';
import { Sidebar, ChatWindow, InputBar } from './components';
import { AppLayout, MainArea } from './components/style';
export default function App() {
    const [conversations, setConversations] = useState([]);
    const [activeId, setActiveId] = useState(null);
    const [isStreaming, setIsStreaming] = useState(false);
    const activeConversation = conversations.find(c => c.id === activeId) ?? null;
    const handleNewChat = useCallback(() => setActiveId(null), []);
    const handleSend = useCallback(async (text) => {
        if (isStreaming)
            return;
        let convId = activeId;
        if (!convId) {
            convId = crypto.randomUUID();
            const newConv = { id: convId, title: text.slice(0, 42), messages: [] };
            setConversations(prev => [newConv, ...prev]);
            setActiveId(convId);
        }
        const userMsg = { id: crypto.randomUUID(), role: 'user', content: text };
        const assistantId = crypto.randomUUID();
        const assistantMsg = { id: assistantId, role: 'assistant', content: '', streaming: true };
        setConversations(prev => prev.map(c => c.id === convId
            ? { ...c, messages: [...c.messages, userMsg, assistantMsg] }
            : c));
        setIsStreaming(true);
        try {
            const res = await fetch('/prompt', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ prompt: text }),
            });
            if (!res.ok || !res.body)
                throw new Error(`HTTP ${res.status}`);
            const reader = res.body.getReader();
            const decoder = new TextDecoder();
            let buffer = '';
            outer: while (true) {
                const { done, value } = await reader.read();
                if (done)
                    break;
                buffer += decoder.decode(value, { stream: true });
                const lines = buffer.split('\n');
                buffer = lines.pop() ?? '';
                for (const line of lines) {
                    if (!line.startsWith('data: '))
                        continue;
                    const data = line.slice(6).trim();
                    if (data === '[DONE]')
                        break outer;
                    try {
                        const json = JSON.parse(data);
                        if (json.response) {
                            setConversations(prev => prev.map(c => c.id === convId
                                ? {
                                    ...c,
                                    messages: c.messages.map(m => m.id === assistantId
                                        ? { ...m, content: m.content + json.response }
                                        : m),
                                }
                                : c));
                        }
                    }
                    catch { /* malformed JSON chunk — skip */ }
                }
            }
        }
        catch {
            setConversations(prev => prev.map(c => c.id === convId
                ? {
                    ...c,
                    messages: c.messages.map(m => m.id === assistantId
                        ? { ...m, content: 'Error: could not reach the API.' }
                        : m),
                }
                : c));
        }
        finally {
            setConversations(prev => prev.map(c => c.id === convId
                ? {
                    ...c,
                    messages: c.messages.map(m => m.id === assistantId ? { ...m, streaming: false } : m),
                }
                : c));
            setIsStreaming(false);
        }
    }, [activeId, isStreaming]);
    return (_jsxs(AppLayout, { children: [_jsx(Sidebar, { conversations: conversations, activeId: activeId, onSelect: setActiveId, onNewChat: handleNewChat }), _jsxs(MainArea, { children: [_jsx(ChatWindow, { conversation: activeConversation }), _jsx(InputBar, { onSend: handleSend, disabled: isStreaming })] })] }));
}
