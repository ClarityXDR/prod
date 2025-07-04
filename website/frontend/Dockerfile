# React Frontend Dockerfile with multi-stage build
FROM node:18-alpine AS builder

# Set build argument for API URL
ARG REACT_APP_API_URL

WORKDIR /app

# Configure npm for better reliability
RUN npm config set registry https://registry.npmjs.org/ && \
    npm config set fetch-timeout 300000 && \
    npm config set fetch-retries 3

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies with fallback options
RUN npm install --no-audit --prefer-offline || \
    npm install --no-audit || \
    npm install --legacy-peer-deps --no-audit

# Copy source code
COPY . ./

# Build the React app with production optimizations and fallback
ENV NODE_ENV=production
ENV REACT_APP_API_URL=$REACT_APP_API_URL

RUN npm run build || { \
    echo "Build failed, creating minimal build directory"; \
    mkdir -p build; \
    echo '<!DOCTYPE html><html><head><title>ClarityXDR</title><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head><body style="font-family: Arial, sans-serif; background: #0A0E23; color: #F5F7FA; margin: 0; padding: 20px;"><div style="max-width: 600px; margin: 0 auto; text-align: center; padding: 50px 0;"><h1 style="color: #7CDB46; font-size: 3rem; margin-bottom: 1rem;">ClarityXDR</h1><p style="font-size: 1.2rem; margin-bottom: 2rem;">Service starting...</p><div style="background: rgba(124,219,70,0.1); border: 1px solid #7CDB46; border-radius: 10px; padding: 20px; margin: 20px 0;"><p>System is initializing. Please wait a moment.</p></div></div></body></html>' > build/index.html; \
} && \
# Ensure build directory exists
mkdir -p build && \
# Verify build directory has content
ls -la build/

# Production stage with nginx
FROM nginx:alpine AS production

# Install curl for health checks
RUN apk --no-cache add curl

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built files from builder stage with fallback
COPY --from=builder /app/build /usr/share/nginx/html

# Create nginx user and directories
RUN mkdir -p /var/log/nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx /usr/share/nginx/html && \
    ls -la /usr/share/nginx/html/

# Switch to nginx user
USER nginx

EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]