cấu trúc mong đợi:
```lua
├── backend/
│   ├── build-logic/                     # (optional) convention plugins (Gradle)
│   ├── libs/                            # shared libs (java)
│   │   ├── common-core/                 # util: errors, logging, tracing helpers
│   │   ├── common-web/                  # web mvc filters, request-id, error handler
│   │   ├── common-security/             # jwt, auth helpers
│   │   ├── common-events/               # event schema + serializer
│   │   └── common-outbox/               # outbox publisher abstraction
│   │
│   ├── services/
│   │   ├── api-gateway/
│   │   │   ├── src/main/java/...
│   │   │   ├── src/main/resources/
│   │   │   │   ├── application.yml
│   │   │   │   ├── application-dev.yml
│   │   │   │   └── application-prod.yml
│   │   │   ├── Dockerfile
│   │   │   └── pom.xml (or build.gradle)
│   │   │
│   │   ├── identity-service/
│   │   │   ├── src/main/resources/
│   │   │   │   ├── db/migration/
│   │   │   │   │   └── V1__init.sql
│   │   │   │   └── application-*.yml
│   │   │   ├── Dockerfile
│   │   │   └── ...
│   │   │
│   │   ├── catalog-service/
│   │   ├── cart-service/
│   │   ├── order-service/
│   │   ├── inventory-service/
│   │   ├── payment-service/
│   │   ├── notification-service/
│   │   └── bff-service/                 # (optional) backend-for-frontend
│   │
│   ├── contracts/
│   │   ├── openapi/                      # source of truth API
│   │   │   ├── order-service.yaml
│   │   │   ├── payment-service.yaml
│   │   │   └── ...
│   │   ├── events/                       # event schema (versioned)
│   │   │   ├── order.events.v1.json
│   │   │   ├── payment.events.v1.json
│   │   │   └── inventory.events.v1.json
│   │   └── generated/                    # (optional) generated clients
│   │
│   └── tools/
│       ├── local-dev/                    # helper scripts
│       │   ├── create-topics.sh
│       │   ├── seed-db.sh
│       │   └── wait-for.sh
│       └── load-test/                    # k6/jmeter
│           ├── checkout.js
│           └── payment-webhook.js
```