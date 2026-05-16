import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { createTheme, ThemeProvider, CssBaseline } from '@mui/material';
import App from './App';

const theme = createTheme({
  palette: {
    mode: 'dark',
    background: { default: '#212121', paper: '#2f2f2f' },
    primary: { main: '#19c37d' },
  },
  typography: {
    fontFamily: 'ui-sans-serif, system-ui, sans-serif',
  },
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <App />
    </ThemeProvider>
  </StrictMode>
);
