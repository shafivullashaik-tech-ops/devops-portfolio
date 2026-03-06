# Demo Microservice Application

Production-ready Node.js/Express microservice demonstrating DevOps best practices.

## Features

- RESTful API with CRUD operations
- Health checks for Kubernetes liveness/readiness probes
- Prometheus metrics endpoint
- Structured logging with Winston
- Security hardening with Helmet
- Multi-stage Docker build
- Helm chart for Kubernetes deployment
- Unit and integration tests with Jest
- CI/CD integration with Jenkins

## Quick Start

### Local Development

```bash
npm install
npm run dev
npm test
```

### Docker Build

```bash
docker build -t demo-app:latest .
docker run -p 3000:3000 demo-app:latest
```

### Kubernetes Deployment

```bash
helm install demo-app ./helm \
  --set image.repository=YOUR_ECR_REPO \
  --set image.tag=latest
```

## Project Structure

```
app-microservice-demo/
├── src/
│   ├── app.js              # Main application
│   ├── logger.js           # Winston logger
│   └── routes/
│       └── api.js          # API routes
├── tests/
│   ├── unit/
│   └── integration/
├── helm/                   # Helm chart
├── Dockerfile              # Multi-stage build
├── Jenkinsfile             # CI/CD pipeline
└── package.json
```

## API Endpoints

### Application
- `GET /` - Application information
- `GET /health` - Health check (liveness)
- `GET /ready` - Readiness check
- `GET /metrics` - Prometheus metrics

### API Routes
- `GET /api/items` - Get all items
- `GET /api/items/:id` - Get item by ID
- `POST /api/items` - Create item
- `PUT /api/items/:id` - Update item
- `DELETE /api/items/:id` - Delete item

## Testing

```bash
npm test                    # All tests
npm run test:unit          # Unit tests only
npm run test:integration   # Integration tests only
npm test -- --coverage     # With coverage
```

## Monitoring

### Prometheus Metrics

Exposes metrics at `/metrics`:
- `nodejs_version_info` - Node.js version
- `process_cpu_user_seconds_total` - CPU usage
- `http_requests_total` - HTTP request counter

### Health Checks

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
readinessProbe:
  httpGet:
    path: /ready
    port: 3000
```

## Docker

### Multi-Stage Build

- Builder stage: Install dependencies
- Production stage: Copy necessary files, run as non-root

Benefits:
- Smaller image size (~150MB)
- Non-root user (UID 1001)
- Layer caching

## Kubernetes

### Helm Chart

Includes:
- Deployment with configurable replicas
- Service (ClusterIP)
- Ingress (optional)
- HorizontalPodAutoscaler (optional)
- ServiceAccount with IRSA support

## Security

- Non-root container user
- Dropped capabilities
- Security headers (Helmet middleware)
- Input validation
- CORS configuration

### Security Scanning

CI pipeline includes:
- Trivy for image CVE scanning
- npm audit for dependency vulnerabilities
- Hadolint for Dockerfile linting

## CI/CD Pipeline

### Jenkins Stages

1. Checkout
2. Build Docker image
3. Run tests
4. Security scanning
5. Push to ECR
6. Update GitOps repository
7. Notify

### GitOps Workflow

```
Developer → Git Push → Jenkins → Build/Test/Scan → ECR → GitOps Update → ArgoCD → Kubernetes
```

---

**Status**: Production-ready microservice
