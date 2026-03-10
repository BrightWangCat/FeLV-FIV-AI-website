import axios from "axios";

// Production: empty string (same-origin via Nginx reverse proxy)
// Development: set VITE_API_BASE_URL=http://localhost:8000 in .env.local
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "";

const api = axios.create({
  baseURL: API_BASE_URL,
});

// Export base URL for components that build URLs outside of axios (e.g. <a href>)
export { API_BASE_URL };

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export function uploadSingle(formData, onUploadProgress) {
  return api.post("/api/upload/single", formData, {
    headers: { "Content-Type": "multipart/form-data" },
    onUploadProgress,
  });
}

export default api;
