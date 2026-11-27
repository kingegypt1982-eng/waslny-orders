const configuredApiUrl = import.meta.env.VITE_API_URL?.trim()

export const API_BASE_URL = configuredApiUrl || (import.meta.env.DEV ? 'http://localhost:3000/api/v1' : '')

if (!API_BASE_URL) {
  throw new Error('VITE_API_URL must be set when building the admin app for production.')
}