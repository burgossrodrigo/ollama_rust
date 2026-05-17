import styled, { keyframes } from 'styled-components';
// ── Layout ────────────────────────────────────────────────────────────────────
export const AppLayout = styled.div `
  display: flex;
  height: 100vh;
  width: 100vw;
  background: #212121;
  color: #ececec;
  font-family: ui-sans-serif, system-ui, sans-serif;
  overflow: hidden;
`;
export const MainArea = styled.div `
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
`;
// ── Sidebar ───────────────────────────────────────────────────────────────────
export const SidebarWrapper = styled.nav `
  width: 260px;
  min-width: 260px;
  background: #171717;
  display: flex;
  flex-direction: column;
  padding: 8px 0;
  overflow: hidden;
`;
export const SidebarHeader = styled.div `
  padding: 8px 12px 12px;
  display: flex;
  align-items: center;
  justify-content: space-between;
`;
export const SidebarTitle = styled.span `
  font-size: 15px;
  font-weight: 600;
  color: #ececec;
`;
export const SidebarItems = styled.div `
  flex: 1;
  overflow-y: auto;
  padding: 0 8px;

  &::-webkit-scrollbar { width: 4px; }
  &::-webkit-scrollbar-track { background: transparent; }
  &::-webkit-scrollbar-thumb { background: #3e3e3e; border-radius: 2px; }
`;
export const ConvItem = styled.button `
  width: 100%;
  background: ${p => p.$active ? '#2a2a2a' : 'transparent'};
  color: #ececec;
  border: none;
  border-radius: 8px;
  padding: 10px 12px;
  text-align: left;
  cursor: pointer;
  font-size: 14px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin-bottom: 2px;
  transition: background 0.12s;
  display: block;

  &:hover {
    background: ${p => p.$active ? '#2a2a2a' : '#202020'};
  }
`;
// ── Chat window ───────────────────────────────────────────────────────────────
export const MessagesContainer = styled.div `
  flex: 1;
  overflow-y: auto;
  padding: 24px 0 8px;

  &::-webkit-scrollbar { width: 6px; }
  &::-webkit-scrollbar-track { background: transparent; }
  &::-webkit-scrollbar-thumb { background: #3e3e3e; border-radius: 3px; }
`;
export const MessageRow = styled.div `
  display: flex;
  flex-direction: ${p => p.$role === 'user' ? 'row-reverse' : 'row'};
  gap: 12px;
  align-items: flex-start;
  max-width: 768px;
  margin: 0 auto 16px;
  padding: 0 24px;
`;
export const Avatar = styled.div `
  width: 32px;
  height: 32px;
  min-width: 32px;
  border-radius: 50%;
  background: ${p => p.$role === 'user' ? '#19c37d' : '#ab68ff'};
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 13px;
  font-weight: 700;
  color: #fff;
  margin-top: 2px;
`;
export const Bubble = styled.div `
  background: ${p => p.$role === 'user' ? '#2f2f2f' : 'transparent'};
  border-radius: ${p => p.$role === 'user' ? '18px 18px 4px 18px' : '0'};
  padding: ${p => p.$role === 'user' ? '10px 16px' : '4px 0'};
  font-size: 15px;
  line-height: 1.65;
  color: #ececec;
  max-width: 85%;
  word-break: break-word;

  p { margin: 0 0 8px; }
  p:last-child { margin-bottom: 0; }

  pre {
    background: #1a1a1a;
    border-radius: 8px;
    padding: 12px;
    overflow-x: auto;
    font-size: 13px;
    margin: 8px 0;
  }

  code {
    background: #1a1a1a;
    border-radius: 4px;
    padding: 2px 5px;
    font-size: 13px;
  }

  pre code {
    background: transparent;
    padding: 0;
  }
`;
// ── Cursor blink animation ────────────────────────────────────────────────────
const blink = keyframes `
  0%, 100% { opacity: 1; }
  50%       { opacity: 0; }
`;
export const Cursor = styled.span `
  display: inline-block;
  width: 2px;
  height: 1em;
  background: #ececec;
  margin-left: 2px;
  vertical-align: text-bottom;
  animation: ${blink} 1s step-end infinite;
`;
// ── Empty state ───────────────────────────────────────────────────────────────
export const EmptyState = styled.div `
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: #6e6e80;
  gap: 12px;
  user-select: none;
`;
export const EmptyTitle = styled.h2 `
  font-size: 24px;
  font-weight: 600;
  color: #ececec;
`;
export const EmptySub = styled.p `
  font-size: 14px;
  color: #6e6e80;
`;
// ── Input bar ─────────────────────────────────────────────────────────────────
export const InputWrapper = styled.div `
  padding: 12px 24px 24px;
  max-width: 768px;
  margin: 0 auto;
  width: 100%;
  box-sizing: border-box;
`;
export const InputInner = styled.div `
  display: flex;
  align-items: flex-end;
  background: #2f2f2f;
  border-radius: 16px;
  padding: 8px 8px 8px 16px;
  gap: 8px;
  transition: box-shadow 0.15s;

  &:focus-within {
    box-shadow: 0 0 0 2px #555;
  }
`;
export const StyledTextarea = styled.textarea `
  flex: 1;
  background: transparent;
  border: none;
  outline: none;
  color: #ececec;
  font-size: 15px;
  line-height: 1.5;
  resize: none;
  min-height: 24px;
  max-height: 200px;
  font-family: inherit;
  padding: 4px 0;
  overflow-y: auto;

  &::placeholder { color: #6e6e80; }

  &::-webkit-scrollbar { width: 4px; }
  &::-webkit-scrollbar-thumb { background: #555; border-radius: 2px; }
`;
export const Hint = styled.p `
  text-align: center;
  font-size: 12px;
  color: #6e6e80;
  margin-top: 8px;
`;
