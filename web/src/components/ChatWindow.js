import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useRef } from 'react';
import SmartToyOutlinedIcon from '@mui/icons-material/SmartToyOutlined';
import { MessagesContainer, EmptyState, EmptyTitle, EmptySub } from './style';
import { MessageBubble } from './MessageBubble';
export function ChatWindow({ conversation }) {
    const bottomRef = useRef(null);
    useEffect(() => {
        bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, [conversation?.messages]);
    if (!conversation || conversation.messages.length === 0) {
        return (_jsxs(EmptyState, { children: [_jsx(SmartToyOutlinedIcon, { sx: { fontSize: 48, color: '#ab68ff' } }), _jsx(EmptyTitle, { children: "How can I help you?" }), _jsx(EmptySub, { children: "Powered by Ollama \u00B7 Qwen3" })] }));
    }
    return (_jsxs(MessagesContainer, { children: [conversation.messages.map(msg => (_jsx(MessageBubble, { message: msg }, msg.id))), _jsx("div", { ref: bottomRef })] }));
}
