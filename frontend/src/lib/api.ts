import type { Product } from './types';

// Runtime environment configuration (injected at deployment time)
declare global {
  interface Window {
    __ENV?: {
      VITE_API_URL?: string;
    };
  }
}

// Get API URL from runtime config (priority) or build-time env variable
// Priority: window.__ENV (runtime) > import.meta.env (build-time) > fallback
const API_URL =
  window.__ENV?.VITE_API_URL ||
  import.meta.env.VITE_API_URL ||
  'https://your-api-id.execute-api.us-east-1.amazonaws.com/Prod';

// Log the API URL for debugging (only in development)
if (import.meta.env.DEV) {
  console.log('API URL:', API_URL);
  console.log('Runtime config:', window.__ENV);
  console.log('Build-time config:', import.meta.env.VITE_API_URL);
}

export const api = {
  // List all products
  async listProducts(): Promise<Product[]> {
    const response = await fetch(`${API_URL}/products`);
    if (!response.ok) {
      throw new Error(`Error ${response.status}: ${response.statusText}`);
    }
    const data = await response.json();
    // API returns {products: [...]}
    return data.products || [];
  },

  // Get a single product
  async getProduct(productId: string): Promise<Product> {
    const response = await fetch(`${API_URL}/products/${productId}`);
    if (!response.ok) {
      throw new Error(`Error ${response.status}: ${response.statusText}`);
    }
    return response.json();
  },

  // Create a new product
  async createProduct(product: Omit<Product, 'product_id' | 'created_at' | 'updated_at'>): Promise<Product> {
    const response = await fetch(`${API_URL}/products`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(product),
    });

    if (!response.ok) {
      throw new Error(`Error ${response.status}: ${response.statusText}`);
    }

    return response.json();
  },

  // Update a product
  async updateProduct(
    productId: string,
    updates: Partial<Omit<Product, 'product_id' | 'created_at' | 'updated_at'>>
  ): Promise<Product> {
    const response = await fetch(`${API_URL}/products/${productId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(updates),
    });

    if (!response.ok) {
      throw new Error(`Error ${response.status}: ${response.statusText}`);
    }

    return response.json();
  },

  // Delete a product
  async deleteProduct(productId: string): Promise<void> {
    const response = await fetch(`${API_URL}/products/${productId}`, {
      method: 'DELETE',
    });

    if (!response.ok) {
      throw new Error(`Error ${response.status}: ${response.statusText}`);
    }
  },
};
