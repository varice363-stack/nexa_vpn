import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        base: '#05070F',
        surface: '#0B0F1A',
        elevated: '#121826',
        accent: '#3D8BFF',
        accentbright: '#6FB1FF',
        premium: '#F5C04B',
        success: '#34D399',
        warning: '#FBBF24',
        danger: '#F87171',
        text: '#F2F5FA',
        muted: '#9AA5B8',
        faint: '#5C6A82',
      },
      borderRadius: {
        glass: '20px',
      },
      boxShadow: {
        glow: '0 0 40px rgba(61, 139, 255, 0.25)',
      },
    },
  },
  plugins: [],
};

export default config;
