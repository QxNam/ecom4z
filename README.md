![E-Commerce Microservice Platform](assets/ecom4z-banner.png)
# 🛒 E-Commerce Microservice Platform

A **production-ready e-commerce platform** built with **Spring Boot microservices**, **Kafka event-driven architecture**, **PostgreSQL**, and a modern **Web UI**.  
Designed for scalability, reliability, and real-world enterprise deployment.

---

## 1. Overview

This project implements a fullstack e-commerce system following:
- **Microservice architecture**
- **Domain-driven design (DDD)**
- **Event-driven communication (Kafka)**
- **Production-grade observability & DevOps practices**

### Key Features
- User authentication & authorization
- Product catalog & inventory management
- Cart & checkout flow
- Order lifecycle with Saga pattern
- Payment integration (idempotent & auditable)
- Real-time event processing
- Centralized monitoring, logging, and tracing

---

## 2. Architecture

### High-level Architecture

Client  
→ Web UI (Customer / Admin)  
→ API Gateway  
→ Microservices (Order, Inventory, Payment, ...)  
→ PostgreSQL / Redis  
→ Kafka (Events)

Detailed diagrams are available in `docs/architecture/`.

---

## 3. Tech Stack

### Backend
- Java 21
- Spring Boot (MVC, Security, Data JPA)
- Kafka
- PostgreSQL
- Redis
- Flyway
- OpenAPI / Swagger

### Frontend
- React / Next.js
- Dockerized build

### Observability
- Prometheus
- Grafana
- Loki + Promtail
- OpenTelemetry
- Jaeger / Tempo
- Alertmanager

### DevOps
- Docker & Docker Compose
- Kubernetes / Helm
- GitHub Actions

---

## 4. Repository Structure

```
ecom-platform/
├── backend/
├── frontend/
├── infra/
├── docs/
├── ci/
├── Makefile
└── README.md
```

---

## 5. Microservices

| Service | Responsibility |
|------|---------------|
| api-gateway | Routing, auth, rate limit |
| identity-service | Users & auth |
| catalog-service | Products |
| cart-service | Shopping cart |
| order-service | Order lifecycle |
| inventory-service | Stock |
| payment-service | Payments |
| notification-service | Notifications |

---

## 6. Data & Events

- Database per service (PostgreSQL)
- Redis for cart & cache
- Kafka for domain events
- Outbox pattern + idempotent consumers

---

## 7. Observability

- `/actuator/health`
- `/actuator/prometheus`
- Distributed tracing via OpenTelemetry

Configs: `infra/observability/`

---

## 8. Run Locally

### Prerequisites
- Docker
- Java 21
- Node.js 18+

### Start
1. Run infrastructure:
```bash
make infra-up
```

---

## 9. Database Migration

- Managed by Flyway
- Hibernate auto-DDL disabled in production

---

## 10. CI/CD

- Build, test, scan
- Docker image publish
- Kubernetes deploy

---

## 11. Security

- OAuth2 / JWT
- RBAC
- Rate limit
- Idempotency keys
- Audit logs

---

## 12. Documentation

- Architecture: `docs/architecture`
- ADRs: `docs/decisions`
- Runbooks: `docs/runbook`

---

## 13. License

MIT / Internal Use
