import { useEffect, useRef } from 'react';
import SmartToyOutlinedIcon from '@mui/icons-material/SmartToyOutlined';
import { MessagesContainer, EmptyState, EmptyTitle, EmptySub } from './style';
import { MessageBubble } from './MessageBubble';
import type { Conversation } from '../types';

interface Props {
  conversation: Conversation | null;
}

export function ChatWindow({ conversation }: Props) {
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [conversation?.messages]);

  if (!conversation || conversation.messages.length === 0) {
    return (
      <EmptyState>
        <SmartToyOutlinedIcon sx={{ fontSize: 48, color: '#ab68ff' }} />
        <EmptyTitle>How can I help you?</EmptyTitle>
        <EmptySub>Powered by Ollama · Qwen3</EmptySub>
      </EmptyState>
    );
  }

  return (
    <MessagesContainer>
      {conversation.messages.map(msg => (
        <MessageBubble key={msg.id} message={msg} />
      ))}
      <div ref={bottomRef} />
    </MessagesContainer>
  );
}
