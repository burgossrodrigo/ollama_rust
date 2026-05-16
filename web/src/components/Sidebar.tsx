import { Tooltip, IconButton } from '@mui/material';
import AddIcon from '@mui/icons-material/Add';
import ChatBubbleOutlineIcon from '@mui/icons-material/ChatBubbleOutline';
import {
  SidebarWrapper,
  SidebarHeader,
  SidebarTitle,
  SidebarItems,
  ConvItem,
} from './style';
import type { Conversation } from '../types';

interface Props {
  conversations: Conversation[];
  activeId: string | null;
  onSelect: (id: string) => void;
  onNewChat: () => void;
}

export function Sidebar({ conversations, activeId, onSelect, onNewChat }: Props) {
  return (
    <SidebarWrapper>
      <SidebarHeader>
        <SidebarTitle>Ollama Chat</SidebarTitle>
        <Tooltip title="New chat">
          <IconButton size="small" onClick={onNewChat} sx={{ color: '#ececec' }}>
            <AddIcon fontSize="small" />
          </IconButton>
        </Tooltip>
      </SidebarHeader>

      <SidebarItems>
        {conversations.length === 0 && (
          <ConvItem as="div" style={{ color: '#6e6e80', cursor: 'default' }}>
            No conversations yet
          </ConvItem>
        )}
        {conversations.map(conv => (
          <Tooltip key={conv.id} title={conv.title} placement="right" arrow>
            <ConvItem $active={conv.id === activeId} onClick={() => onSelect(conv.id)}>
              <ChatBubbleOutlineIcon
                sx={{ fontSize: 14, mr: 1, verticalAlign: 'middle', opacity: 0.6 }}
              />
              {conv.title}
            </ConvItem>
          </Tooltip>
        ))}
      </SidebarItems>
    </SidebarWrapper>
  );
}
