
# ---------------------------------
# Stage 1: Build the React application
# ---------------------------------
FROM node:26-alpine AS build

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy application source code
COPY . .

# Build production application
RUN npm run build


# ---------------------------------
# Stage 2: Production runtime
# ---------------------------------
FROM nginx:alpine AS production

# Copy production files from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Docker health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1 
