import '@testing-library/jest-dom';
import { expect, afterEach, vi } from 'vitest';
import { cleanup } from '@testing-library/react';

// Cleanup after each test
afterEach(() => {
  cleanup();
});

// Mock window.__ENV for tests
globalThis.window = globalThis.window || ({} as any);
window.__ENV = {
  VITE_API_URL: 'https://test-api.example.com/Prod'
};

// Mock fetch globally
global.fetch = vi.fn();
