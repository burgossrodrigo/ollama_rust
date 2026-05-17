import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
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
createRoot(document.getElementById('root')).render(_jsx(StrictMode, { children: _jsxs(ThemeProvider, { theme: theme, children: [_jsx(CssBaseline, {}), _jsx(App, {})] }) }));
