import { jsxs as _jsxs, jsx as _jsx, Fragment as _Fragment } from "react/jsx-runtime";
import { useState, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import { MessageRow, Avatar, Bubble, Cursor, ThinkingLabel } from './style';
function ThinkingTimer() {
    const [seconds, setSeconds] = useState(0);
    useEffect(() => {
        const id = setInterval(() => setSeconds(s => s + 1), 1000);
        return () => clearInterval(id);
    }, []);
    return _jsxs(ThinkingLabel, { children: ["\u23F1 Pensando h\u00E1 ", seconds, "s..."] });
}
export function MessageBubble({ message }) {
    const isUser = message.role === 'user';
    return (_jsxs(MessageRow, { "$role": message.role, children: [_jsx(Avatar, { "$role": message.role, children: isUser ? 'U' : 'AI' }), _jsx(Bubble, { "$role": message.role, children: isUser ? (message.content) : (_jsxs(_Fragment, { children: [message.thinking && _jsx(ThinkingTimer, {}), message.content && _jsx(ReactMarkdown, { children: message.content }), message.streaming && !message.thinking && _jsx(Cursor, {})] })) })] }));
}
