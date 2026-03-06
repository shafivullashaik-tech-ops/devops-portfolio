# Demo Microservice Application

A production-ready Node.js/Express microservice demonstrating DevOps best practices.

## 🎯 Features

- **RESTful API** with CRUD operations
- **Health checks** for Kubernetes liveness/readiness probes
- **Prometheus metrics** endpoint
- **Structured logging** with Winston
- **Security hardening** with Helmet
- **Multi-stage Docker build** for optimization
- **Kubernetes-ready** with Helm chart
- **Unit and integration tests** with Jest
- **CI/CD integration** with Jenkins

## 🚀 Quick Start

### Local Development

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev

# Run tests
npm test

# Run linter
npm run lint
```

### Docker Build

```bash
# Build image
docker build -t demo-app:latest \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  --build-arg VERSION=1.0.0 \
  .

# Run container
docker run -p 3000:3000 demo-app:latest

# Test endpoints
curl http://localhost:3000/health
curl http://localhost:3000/metrics
curl http://localhost:3000/api/items
```

### Kubernetes Deployment

```bash
# Deploy with Helm
helm install demo-app ./helm \
  --set image.repository=YOUR_ECR_REPO \
  --set image.tag=latest

# Check deployment
kubectl get pods
kubectl get svc

# Port forward to test locally
kubectl port-forward svc/demo-app 3000:3000
```

## 📁 Project Structure

```
app-microservice-demo/
├── src/
│   ├── app.js              # Main application
│   ├── logger.js           # Winston logger configuration
│   └── routes/
│       └── api.js          # API routes
├── tests/
│   ├── unit/
│   │   └── app.test.js     # Unit tests
│   └── integration/
│       └── api.test.js     # Integration tests
├── helm/
│   ├── Chart.yaml          # Helm chart metadata
│   ├── values.yaml         # Default values
│   └── templates/          # Kubernetes manifests
├── Dockerfile              # Multi-stage build
├── .dockerignore           # Docker ignore file
├── Jenkinsfile             # CI/CD pipeline
├── package.json            # Node.js dependencies
└── README.md               # This file
```

## 🔌 API Endpoints

### Application Endpoints

- **GET /** - Application information
- **GET /health** - Health check (Kubernetes liveness)
- **GET /ready** - Readiness check (Kubernetes readiness)
- **GET /metrics** - Prometheus metrics

### API Routes

- **GET /api/items** - Get all items
- **GET /api/items/:id** - Get item by ID
- **POST /api/items** - Create new item
- **PUT /api/items/:id** - Update item
- **DELETE /api/items/:id** - Delete item

### Example Request

```bash
# Create item
curl -X POST http://localhost:3000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item","description":"Test Description"}'

# Get all items
curl http://localhost:3000/api/items

# Update item
curl -X PUT http://localhost:3000/api/items/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Item"}'

# Delete item
curl -X DELETE http://localhost:3000/api/items/1
```

## 🧪 Testing

```bash
# Run all tests
npm test

# Run unit tests only
npm run test:unit

# Run integration tests only
npm run test:integration

# Run tests in watch mode
npm run test:watch

# Run with coverage
npm test -- --coverage
```

## 📊 Monitoring

### Prometheus Metrics

The `/metrics` endpoint exposes metrics in Prometheus format:

```
# HELP nodejs_version_info Node.js version info
# TYPE nodejs_version_info gauge
nodejs_version_info{version="v18.0.0",major="18",minor="0",patch="0"} 1

# HELP process_cpu_user_seconds_total Total user CPU time spent
# TYPE process_cpu_user_seconds_total counter
process_cpu_user_seconds_total 0.5

# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",route="/api/items",status="200"} 10
```

### Health Checks

Kubernetes uses these endpoints:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
```

## 🐳 Docker

### Multi-Stage Build

The Dockerfile uses multi-stage builds:

1. **Builder stage**: Install dependencies
2. **Production stage**: Copy only necessary files, run as non-root

Benefits:
- Smaller image size (~150MB vs 1GB+)
- Better security (non-root user)
- Faster builds (layer caching)

### OCI Labels

Images include standard OCI labels:

```dockerfile
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
```

## ☸️ Kubernetes

### Helm Chart

The included Helm chart provides:

- **Deployment** with configurable replicas
- **Service** (ClusterIP by default)
- **Ingress** (optional)
- **HorizontalPodAutoscaler** (optional)
- **ServiceAccount** with IRSA support
- **ConfigMaps** for configuration
- **Secrets** integration

### Values Configuration

```yaml
# values.yaml
replicaCount: 2
image:
  repository: YOUR_ECR_REPO
  tag: latest
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

## 🔐 Security

### Security Features

1. **Non-root user**: Container runs as user 1001
2. **Read-only root filesystem**: (configurable)
3. **Dropped capabilities**: All capabilities dropped
4. **No privilege escalation**: Prevented
5. **Security headers**: Helmet middleware
6. **Input validation**: Express JSON parser
7. **CORS configuration**: Configurable CORS

### Security Scanning

CI pipeline includes:

- **Trivy**: Scans for CVEs in Docker image
- **npm audit**: Checks for vulnerable dependencies
- **Hadolint**: Lints Dockerfile for best practices

## 🔄 CI/CD

### Jenkins Pipeline

The Jenkinsfile defines a 7-stage pipeline:

1. **Checkout** - Clone repository
2. **Build** - Build Docker image
3. **Test** - Run unit and integration tests
4. **Security Scan** - Trivy and Hadolint
5. **Push to ECR** - Push to AWS ECR
6. **Update GitOps** - Update image tag in GitOps repo
7. **Notify** - Send notifications

### GitOps Workflow

```
Developer → Git Push → Jenkins Build → ECR Push → GitOps Update → ArgoCD Sync → Kubernetes
```

## 🎤 Interview Talking Points

### Q: "Walk me through your application architecture"

**A**: "This is a Node.js/Express microservice designed for Kubernetes. It exposes a RESTful API with CRUD operations, health check endpoints for Kubernetes probes, and a Prometheus metrics endpoint for observability.

The application follows 12-factor app principles:
- Stateless (no local storage)
- Config via environment variables
- Logs to stdout
- Graceful shutdown on SIGTERM

Security is built-in with Helmet middleware, non-root container user, and dropped capabilities."

### Q: "How do you ensure zero-downtime deployments?"

**A**: "Multiple layers:

1. **Readiness probes**: Kubernetes doesn't route traffic until /ready returns 200
2. **Rolling updates**: Kubernetes deployment strategy
3. **Resource requests/limits**: Prevents resource contention
4. **PodDisruptionBudget**: Ensures minimum replicas always available
5. **Graceful shutdown**: Application handles SIGTERM to finish in-flight requests

The combination ensures users never hit a non-ready pod."

### Q: "How do you monitor this application?"

**A**: "Three layers:

1. **Metrics**: Prometheus scrapes /metrics every 15s for RED metrics (Rate, Errors, Duration)
2. **Logs**: Structured JSON logs to stdout, collected by FluentBit to CloudWatch
3. **Traces**: (Future) OpenTelemetry for distributed tracing

Grafana dashboards visualize:
- Request rate and latency (p50, p95, p99)
- Error rate
- Resource usage (CPU, memory)
- Custom business metrics"

## 📖 Resources

- [Express.js Documentation](https://expressjs.com/)
- [Helm Charts](https://helm.sh/docs/topics/charts/)
- [12-Factor App](https://12factor.net/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

---

**Built by**: Shaik Shafivulla
**Status**: Production-ready microservice for portfolio demonstration
