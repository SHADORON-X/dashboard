/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    darkMode: 'class',
    theme: {
        extend: {
            colors: {
                velmo: {
                    50: '#f0f4ff',
                    100: '#e0e9ff',
                    200: '#c7d6fe',
                    300: '#a5b9fc',
                    400: '#8193f8',
                    500: '#636df1',
                    600: '#4f4ce5',
                    700: '#423dca',
                    800: '#3734a3',
                    900: '#313281',
                    950: '#1e1d4b',
                },
                dark: {
                    50: '#f6f6f7',
                    100: '#e3e3e5',
                    200: '#c6c6cb',
                    300: '#a2a2a9',
                    400: '#7d7d86',
                    500: '#62626b',
                    600: '#4e4e55',
                    700: '#404045',
                    800: '#27272a',
                    900: '#18181b',
                    950: '#09090b',
                }
            },
            fontFamily: {
                sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
                mono: ['JetBrains Mono', 'Fira Code', 'monospace'],
            },
            animation: {
                'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
                'fade-in': 'fadeIn 0.3s ease-in-out',
                'slide-up': 'slideUp 0.3s ease-out',
            },
            keyframes: {
                fadeIn: {
                    '0%': { opacity: '0' },
                    '100%': { opacity: '1' },
                },
                slideUp: {
                    '0%': { opacity: '0', transform: 'translateY(10px)' },
                    '100%': { opacity: '1', transform: 'translateY(0)' },
                },
            },
        },
    },
    plugins: [],
}
