import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useRef, useCallback } from 'react';
import { IconButton, CircularProgress, Tooltip } from '@mui/material';
import SendIcon from '@mui/icons-material/Send';
import { InputWrapper, InputInner, StyledTextarea, Hint } from './style';
export function InputBar({ onSend, disabled }) {
    const ref = useRef(null);
    const submit = useCallback(() => {
        const text = ref.current?.value.trim();
        if (!text || disabled)
            return;
        ref.current.value = '';
        ref.current.style.height = 'auto';
        onSend(text);
    }, [onSend, disabled]);
    const handleKey = useCallback((e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            submit();
        }
    }, [submit]);
    const autoResize = useCallback(() => {
        const el = ref.current;
        if (!el)
            return;
        el.style.height = 'auto';
        el.style.height = `${Math.min(el.scrollHeight, 200)}px`;
    }, []);
    return (_jsxs(InputWrapper, { children: [_jsxs(InputInner, { children: [_jsx(StyledTextarea, { ref: ref, rows: 1, placeholder: "Message Ollama\u2026", onKeyDown: handleKey, onInput: autoResize, disabled: disabled }), _jsx(Tooltip, { title: disabled ? 'Generating…' : 'Send (Enter)', children: _jsx("span", { children: _jsx(IconButton, { onClick: submit, disabled: disabled, size: "small", sx: {
                                    background: disabled ? '#444' : '#19c37d',
                                    color: '#fff',
                                    '&:hover': { background: '#15a86a' },
                                    '&.Mui-disabled': { background: '#444', color: '#666' },
                                    borderRadius: '10px',
                                    width: 36,
                                    height: 36,
                                }, children: disabled
                                    ? _jsx(CircularProgress, { size: 16, sx: { color: '#888' } })
                                    : _jsx(SendIcon, { sx: { fontSize: 16 } }) }) }) })] }), _jsx(Hint, { children: "Shift+Enter for new line \u00B7 Enter to send" })] }));
}
