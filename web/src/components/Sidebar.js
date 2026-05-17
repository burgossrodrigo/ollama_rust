import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { Tooltip, IconButton } from '@mui/material';
import AddIcon from '@mui/icons-material/Add';
import ChatBubbleOutlineIcon from '@mui/icons-material/ChatBubbleOutline';
import { SidebarWrapper, SidebarHeader, SidebarTitle, SidebarItems, ConvItem, } from './style';
export function Sidebar({ conversations, activeId, onSelect, onNewChat }) {
    return (_jsxs(SidebarWrapper, { children: [_jsxs(SidebarHeader, { children: [_jsx(SidebarTitle, { children: "Ollama Chat" }), _jsx(Tooltip, { title: "New chat", children: _jsx(IconButton, { size: "small", onClick: onNewChat, sx: { color: '#ececec' }, children: _jsx(AddIcon, { fontSize: "small" }) }) })] }), _jsxs(SidebarItems, { children: [conversations.length === 0 && (_jsx(ConvItem, { as: "div", style: { color: '#6e6e80', cursor: 'default' }, children: "No conversations yet" })), conversations.map(conv => (_jsx(Tooltip, { title: conv.title, placement: "right", arrow: true, children: _jsxs(ConvItem, { "$active": conv.id === activeId, onClick: () => onSelect(conv.id), children: [_jsx(ChatBubbleOutlineIcon, { sx: { fontSize: 14, mr: 1, verticalAlign: 'middle', opacity: 0.6 } }), conv.title] }) }, conv.id)))] })] }));
}
