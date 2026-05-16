import { useRef, useCallback, KeyboardEvent } from 'react';
import { IconButton, CircularProgress, Tooltip } from '@mui/material';
import SendIcon from '@mui/icons-material/Send';
import { InputWrapper, InputInner, StyledTextarea, Hint } from './style';

interface Props {
  onSend: (text: string) => void;
  disabled: boolean;
}

export function InputBar({ onSend, disabled }: Props) {
  const ref = useRef<HTMLTextAreaElement>(null);

  const submit = useCallback(() => {
    const text = ref.current?.value.trim();
    if (!text || disabled) return;
    ref.current!.value = '';
    ref.current!.style.height = 'auto';
    onSend(text);
  }, [onSend, disabled]);

  const handleKey = useCallback(
    (e: KeyboardEvent<HTMLTextAreaElement>) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        submit();
      }
    },
    [submit]
  );

  const autoResize = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = `${Math.min(el.scrollHeight, 200)}px`;
  }, []);

  return (
    <InputWrapper>
      <InputInner>
        <StyledTextarea
          ref={ref}
          rows={1}
          placeholder="Message Ollama…"
          onKeyDown={handleKey}
          onInput={autoResize}
          disabled={disabled}
        />
        <Tooltip title={disabled ? 'Generating…' : 'Send (Enter)'}>
          <span>
            <IconButton
              onClick={submit}
              disabled={disabled}
              size="small"
              sx={{
                background: disabled ? '#444' : '#19c37d',
                color: '#fff',
                '&:hover': { background: '#15a86a' },
                '&.Mui-disabled': { background: '#444', color: '#666' },
                borderRadius: '10px',
                width: 36,
                height: 36,
              }}
            >
              {disabled
                ? <CircularProgress size={16} sx={{ color: '#888' }} />
                : <SendIcon sx={{ fontSize: 16 }} />
              }
            </IconButton>
          </span>
        </Tooltip>
      </InputInner>
      <Hint>Shift+Enter for new line · Enter to send</Hint>
    </InputWrapper>
  );
}
