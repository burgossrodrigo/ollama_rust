import ReactMarkdown from 'react-markdown';
import { MessageRow, Avatar, Bubble, Cursor } from './style';
import type { Message } from '../types';

interface Props {
  message: Message;
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
            <ReactMarkdown>{message.content || ' '}</ReactMarkdown>
            {message.streaming && <Cursor />}
          </>
        )}
      </Bubble>
    </MessageRow>
  );
}
