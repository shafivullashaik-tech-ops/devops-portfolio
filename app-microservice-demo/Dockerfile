# Multi-stage Dockerfile for Node.js Application
# Stage 1: Build dependencies
# Stage 2: Production image

# Build Stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Production Stage
FROM node:18-alpine

# Add build arguments for OCI labels
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# OCI Image labels
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="shafivullashaik916@gmail.com" \
      org.opencontainers.image.url="https://github.com/shafivullashaik-tech-ops/devops-portfolio" \
      org.opencontainers.image.source="https://github.com/shafivullashaik-tech-ops/devops-portfolio" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.title="Demo Microservice" \
      org.opencontainers.image.description="DevOps Portfolio Demo Application"

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy dependencies from builder
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application code
COPY --chown=nodejs:nodejs src ./src
COPY --chown=nodejs:nodejs package*.json ./

# Switch to non-root user
USER nodejs

# Expose application port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Set environment variables
ENV NODE_ENV=production \
    PORT=3000

# Start application
CMD ["node", "src/app.js"]
