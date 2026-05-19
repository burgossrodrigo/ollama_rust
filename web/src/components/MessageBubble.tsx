import { useState, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import { MessageRow, Avatar, Bubble, Cursor, ThinkingLabel } from './style';
import type { Message } from '../types';

interface Props {
  message: Message;
}

function ThinkingTimer() {
  const [seconds, setSeconds] = useState(0);

  useEffect(() => {
    const id = setInterval(() => setSeconds(s => s + 1), 1000);
    return () => clearInterval(id);
  }, []);

  return <ThinkingLabel>⏱ Pensando há {seconds}s...</ThinkingLabel>;
}

export function MessageBubble({ message }: Props) {
  const isUser = message.role === 'user';

  return (
    <MessageRow $role={message.role}>
      <Avatar $role={message.role}>{isUser ? 'U' : 'AI'}</Avatar>
      <Bubble $role={message.role}>
        {isUser ? (
          message.content
        ) : (
          <>
            {message.thinking && <ThinkingTimer />}
            {message.content && <ReactMarkdown>{message.content}</ReactMarkdown>}
            {message.streaming && !message.thinking && <Cursor />}
          </>
        )}
      </Bubble>
    </MessageRow>
  );
}
