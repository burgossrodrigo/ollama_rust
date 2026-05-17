import { jsx as _jsx, Fragment as _Fragment, jsxs as _jsxs } from "react/jsx-runtime";
import ReactMarkdown from 'react-markdown';
import { MessageRow, Avatar, Bubble, Cursor } from './style';
export function MessageBubble({ message }) {
    const isUser = message.role === 'user';
    return (_jsxs(MessageRow, { "$role": message.role, children: [_jsx(Avatar, { "$role": message.role, children: isUser ? 'U' : 'AI' }), _jsx(Bubble, { "$role": message.role, children: isUser ? (message.content) : (_jsxs(_Fragment, { children: [_jsx(ReactMarkdown, { children: message.content || ' ' }), message.streaming && _jsx(Cursor, {})] })) })] }));
}
