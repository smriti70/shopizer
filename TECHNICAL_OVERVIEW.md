# Shopizer — Technical & Functional Overview

> Version 3.2.7 · Java 11+ · Spring Boot 2.5.12 · Generated: March 2026

---

## Table of Contents

1. [What is Shopizer?](#1-what-is-shopizer)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Module Structure](#3-module-structure)
4. [Layered Architecture Deep Dive](#4-layered-architecture-deep-dive)
5. [Domain Model](#5-domain-model)
6. [API Design](#6-api-design)
7. [Security Model](#7-security-model)
8. [Integration Modules](#8-integration-modules)
9. [Data & Persistence](#9-data--persistence)
10. [Caching Strategy](#10-caching-strategy)
11. [Key Functional Flows](#11-key-functional-flows)
12. [Configuration & Deployment Profiles](#12-configuration--deployment-profiles)
13. [Tech Stack Summary](#13-tech-stack-summary)

---

## 1. What is Shopizer?

Shopizer is a **Java-based headless e-commerce platform** that exposes a complete REST API for building custom storefronts, admin tools, or mobile apps. It is not a monolithic storefront — it ships no frontend UI. Instead, it provides:

- A fully documented REST API (Swagger at `/swagger-ui.html`)
- Multi-store / marketplace support
- Pluggable payment and shipping modules
- Rules-engine-driven pricing and order totals (Drools)
- CMS content management
- JWT-based authentication for both customers and admin users

---

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        External Clients                         │
│   React Storefront  │  Admin SPA  │  Mobile App  │  3rd Party  │
└────────────┬────────────────────────────────────────────────────┘
             │  HTTP/REST (JSON)
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    sm-shop  (Spring Boot App)                    │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  REST API    │  │   Security   │  │   Swagger / Docs     │  │
│  │  v0 / v1 /v2│  │  JWT Filter  │  │   springfox 2.9.2    │  │
│  └──────┬───────┘  └──────────────┘  └──────────────────────┘  │
│         │                                                       │
│  ┌──────▼───────────────────────────────────────────────────┐  │
│  │                    Facade Layer                           │  │
│  │  Product │ Order │ Customer │ Cart │ Content │ Tax │ ...  │  │
│  └──────┬───────────────────────────────────────────────────┘  │
└─────────┼───────────────────────────────────────────────────────┘
          │
┌─────────▼───────────────────────────────────────────────────────┐
│                    sm-core  (Business Logic)                     │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   Service Layer                           │  │
│  │  ProductService │ OrderService │ PaymentService │ ...     │  │
│  └──────┬───────────────────────────────────────────────────┘  │
│         │                                                       │
│  ┌──────▼───────────────────────────────────────────────────┐  │
│  │               Repository Layer (Spring Data JPA)          │  │
│  └──────┬───────────────────────────────────────────────────┘  │
│         │                                                       │
│  ┌──────▼──────────────┐  ┌──────────────────────────────────┐ │
│  │  Integration Modules│  │  Rules Engine (Drools 7.32)      │ │
│  │  Payment / Shipping │  │  Shipping rules / Order totals   │ │
│  └─────────────────────┘  └──────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
          │
┌─────────▼───────────────────────────────────────────────────────┐
│                    sm-core-model  (JPA Entities)                 │
│   Product │ Order │ Customer │ MerchantStore │ ShoppingCart ...  │
└─────────────────────────────────────────────────────────────────┘
          │
┌─────────▼───────────────────────────────────────────────────────┐
│                         Database                                 │
│         H2 (default dev)  │  MySQL  │  PostgreSQL  │  Oracle     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Module Structure

The project is a **Maven multi-module build** with a parent POM coordinating all modules.

```
shopizer/  (parent pom.xml — BOM + build config)
├── sm-core-model/       ← JPA entities, domain objects, enums
├── sm-core-modules/     ← Integration interfaces (payment, shipping)
├── sm-core/             ← Business services, repositories, config
├── sm-shop-model/       ← API DTOs (request/response objects)
└── sm-shop/             ← Spring Boot app, REST controllers, facades
```

### Dependency Flow

```
sm-shop
  └── depends on → sm-shop-model
  └── depends on → sm-core
                     └── depends on → sm-core-modules
                     └── depends on → sm-core-model
```

Each module is independently buildable. `sm-shop` is the only runnable Spring Boot application.

---

## 4. Layered Architecture Deep Dive

```
┌─────────────────────────────────────────────────────┐
│  Layer 1: REST API Controllers  (sm-shop)            │
│  @RestController  — HTTP in/out, validation          │
│  Packages: store/api/v0, v1, v2                      │
└──────────────────────┬──────────────────────────────┘
                       │ calls
┌──────────────────────▼──────────────────────────────┐
│  Layer 2: Facade Layer  (sm-shop)                    │
│  Orchestrates multiple services, handles             │
│  DTO ↔ Entity conversion via Populators/MapStruct    │
│  Packages: store/facade/*, store/controller/*/facade │
└──────────────────────┬──────────────────────────────┘
                       │ calls
┌──────────────────────▼──────────────────────────────┐
│  Layer 3: Service Layer  (sm-core)                   │
│  Core business logic, transaction boundaries         │
│  Packages: business/services/*                       │
└──────────────────────┬──────────────────────────────┘
                       │ calls
┌──────────────────────▼──────────────────────────────┐
│  Layer 4: Repository Layer  (sm-core)                │
│  Spring Data JPA repositories + custom JPQL queries  │
│  Packages: business/repositories/*                   │
└──────────────────────┬──────────────────────────────┘
                       │ maps to
┌──────────────────────▼──────────────────────────────┐
│  Layer 5: Domain Model  (sm-core-model)              │
│  JPA @Entity classes, all extend SalesManagerEntity  │
│  Packages: model/*                                   │
└─────────────────────────────────────────────────────┘
```

**Key design patterns used:**
- **Facade Pattern** — every domain area has a `XxxFacade` interface + `XxxFacadeImpl`
- **Populator Pattern** — `AbstractDataPopulator<S,T>` converts between entities and DTOs
- **Repository Pattern** — Spring Data JPA with custom query methods
- **Strategy Pattern** — payment and shipping modules are pluggable strategies

---

## 5. Domain Model

### Core Entities

```
MerchantStore (multi-store root)
  ├── has many → Product
  │               ├── ProductDescription (i18n)
  │               ├── ProductAvailability (stock, region)
  │               ├── ProductPrice
  │               ├── ProductImage
  │               ├── ProductAttribute → ProductOption + ProductOptionValue
  │               ├── ProductVariant → ProductVariantGroup
  │               ├── ProductVariation
  │               ├── ProductReview
  │               └── ProductRelationship (upsell/cross-sell)
  │
  ├── has many → Category (hierarchical, self-referencing)
  │
  ├── has many → Order
  │               ├── OrderProduct
  │               │     ├── OrderProductAttribute
  │               │     └── OrderProductPrice
  │               ├── OrderTotal (subtotal, tax, shipping, grand total)
  │               ├── OrderStatusHistory
  │               ├── Transaction (payment record)
  │               └── Billing / Delivery (addresses)
  │
  ├── has many → Customer
  │               ├── CustomerAttribute (custom fields)
  │               ├── CustomerReview
  │               └── ShoppingCart
  │                     └── ShoppingCartItem
  │                           └── ShoppingCartAttributeItem
  │
  ├── has many → User (admin users)
  │               └── Group + Permission (RBAC)
  │
  ├── has many → TaxRate → TaxClass
  ├── has many → Content (CMS pages, boxes)
  └── has many → MerchantConfiguration (key-value store config)

Reference Data (global, not store-scoped):
  Country → Zone (state/province)
  Currency
  Language
  GeoZone (for tax/shipping rules)
```

### Base Entity

All entities extend `SalesManagerEntity<PK, E>` which provides:
- Generic typed primary key
- Audit fields via `AuditSection` (`dateCreated`, `dateModified`, `modifiedBy`)
- `Auditable` interface with `@EntityListeners(AuditListener.class)`

---

## 6. API Design

### Versioning

| Version | Path Prefix | Status |
|---------|-------------|--------|
| v0 | `/api/v0/` | Legacy (system init, store contact) |
| v1 | `/api/v1/` | Primary API — all main endpoints |
| v2 | `/api/v2/` | Extended product variants API |

### v1 API Surface

```
/api/v1/
├── /products                  ← CRUD products, images, reviews
├── /products/type             ← Product types
├── /products/options          ← Attribute options & option sets
├── /products/inventory        ← Stock management
├── /products/price            ← Pricing
├── /products/group            ← Product groups
├── /products/manufacturer     ← Brands/manufacturers
├── /category                  ← Category tree management
├── /catalog                   ← Catalog management
├── /cart                      ← Shopping cart (anonymous + auth)
├── /order                     ← Order lifecycle
├── /order/payment             ← Payment processing
├── /order/shipping            ← Shipping quotes
├── /order/total               ← Order total calculation
├── /customer                  ← Customer CRUD + auth
├── /customer/review           ← Customer reviews
├── /user                      ← Admin user management
├── /store                     ← Merchant store config
├── /tax/rate                  ← Tax rates
├── /tax/class                 ← Tax classes
├── /shipping/configuration    ← Shipping module config
├── /content                   ← CMS content
├── /search                    ← Product search (Elasticsearch)
├── /references                ← Countries, zones, currencies, languages
├── /payment                   ← Payment module config
├── /marketplace               ← Multi-store marketplace
└── /system/                   ← Modules, optin, contact, configs

/api/v2/
├── /products                  ← Enhanced product API
├── /products/variation        ← Product variations
└── /products/variant          ← Product variant groups
```

### Request/Response Pattern

```
HTTP Request
    │
    ▼
@RestController (validates @Valid, resolves MerchantStore + Language from request)
    │
    ▼
Facade.method(PersistableXxx dto, MerchantStore store, Language lang)
    │
    ▼
Returns ReadableXxx (DTO) or Entity id
    │
    ▼
HTTP Response (JSON)
```

`MerchantStore` and `Language` are resolved from request headers/params by `@ModelAttribute` interceptors in most controllers.

---

## 7. Security Model

```
HTTP Request
    │
    ▼
┌─────────────────────────────────────────────────────┐
│  AuthenticationTokenFilter  (OncePerRequestFilter)   │
│  Extracts JWT from Authorization: Bearer <token>     │
│  Validates token → loads UserDetails                 │
└──────────────────────┬──────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
  Admin JWT path              Customer JWT path
  JWTAdminAuthenticationManager   JWTCustomerAuthenticationManager
  JWTAdminAuthenticationProvider  JWTCustomerAuthenticationProvider
          │                         │
          ▼                         ▼
  JWTUser (UserDetails)       CustomerDetails (UserDetails)
```

### Two Separate Auth Realms

| Realm | Login Endpoint | Token Subject | Roles |
|-------|---------------|---------------|-------|
| Admin/User | `POST /api/v1/user/login` | username | `ROLE_ADMIN`, `ROLE_STORE_ADMIN`, etc. |
| Customer | `POST /api/v1/customer/login` | customer email | `ROLE_CUSTOMER` |

### JWT Token Lifecycle

```
POST /login  { username, password }
    │
    ▼
AuthenticationManager.authenticate()
    │
    ▼
JWTTokenUtil.generateToken(UserDetails)  →  JWT (HS512, configurable expiry)
    │
    ▼
Response: { token: "eyJ..." }

Subsequent requests:
Authorization: Bearer eyJ...
    │
    ▼
AuthenticationTokenFilter validates → sets SecurityContext
```

### RBAC

Users belong to `Group`s which have `Permission`s. Groups are typed (`ADMIN`, `STORE_ADMIN`, etc.). Spring Security method-level security (`@PreAuthorize`) is used on facade methods.

---

## 8. Integration Modules

### Payment Modules

```
┌─────────────────────────────────────────────────────┐
│              PaymentService                          │
│  processPayment() / refund() / capture()             │
└──────────────────────┬──────────────────────────────┘
                       │ delegates to
          ┌────────────┼────────────┬──────────────┐
          ▼            ▼            ▼              ▼
       Stripe      PayPal       Braintree    MoneyOrder
    (creditcard)  (express)   (creditcard)   (offline)
```

Modules are configured per-store via `MerchantConfiguration` and loaded from `integrationmodules.json`.

### Shipping Modules

```
┌─────────────────────────────────────────────────────┐
│              ShippingQuoteService                    │
│  getShippingQuotes(cart, destination, store)         │
└──────────────────────┬──────────────────────────────┘
                       │ delegates to active modules
     ┌─────────┬───────┴──────┬──────────┬────────────┐
     ▼         ▼              ▼          ▼            ▼
   USPS    Canada Post       UPS    WeightBased   StorePickUp
   (US)      (CA)         (US/CA/EU)  (custom)    (custom)
```

### Rules Engine (Drools)

Drools 7.32 is used for:
- **Order total processors** — calculating discounts, coupons, taxes applied to order totals
- **Shipping rules** — custom quote rules based on weight, distance, manufacturer

Rules are defined in `.xls` decision tables (`manufacturer-shipping-ordertotal-rules.xls`) and loaded via `DroolsBeanFactory`.

---

## 9. Data & Persistence

### Database Support

| Database | Profile | Notes |
|----------|---------|-------|
| H2 (embedded) | default | Dev only, auto-created, file `SALESMANAGER.h2.db` |
| MySQL 8 | `local`, `mysql`, `docker` | Recommended for production |
| PostgreSQL | `cloud` | Supported via profile switch |
| Oracle | commented out | Available, needs ojdbc8 dependency |

### Schema

- Schema name: `SALESMANAGER` (configurable)
- DDL: `hibernate.hbm2ddl.auto=update` (auto-migrates on startup)
- Connection pool: HikariCP (Spring Boot default)

### JPA Configuration

```
DataConfiguration (sm-core)
  └── configures EntityManagerFactory
  └── configures TransactionManager
  └── scans: com.salesmanager.core.model (entities)
             com.salesmanager.core.business.repositories (repos)
```

### Repository Pattern

```java
// Example: Spring Data JPA with custom queries
public interface ProductRepository extends JpaRepository<Product, Long> {
    // Auto-generated finders + custom @Query JPQL methods
}
```

---

## 10. Caching Strategy

Two caching layers are used:

```
┌─────────────────────────────────────────────────────┐
│  EhCache  (local, in-process)                        │
│  - Reference data: countries, zones, currencies      │
│  - Languages                                         │
│  - Merchant store configurations                     │
│  Config: spring/ehcache.xml                          │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Infinispan 9.4  (distributed, optional)             │
│  - Product catalog cache                             │
│  - Session/cart data                                 │
│  - JDBC cache store backed                           │
└─────────────────────────────────────────────────────┘
```

Spring's `@Cacheable` / `@CacheEvict` annotations are used on service methods. Cache is exposed via Spring Boot Actuator (`/actuator/caches`).

---

## 11. Key Functional Flows

### Product Browse Flow

```
GET /api/v1/products?store=DEFAULT&lang=en&page=0&count=20
    │
    ▼
ProductApi.list()
    │
    ▼
ProductFacade.getProducts(criteria, store, language)
    │
    ▼
ProductService.listByStore(criteria)  →  ProductRepository.findByCriteria()
    │
    ▼
PricingService.calculateProductPrice(product, store)
    │
    ▼
Populator: Product → ReadableProduct (DTO with i18n descriptions, images, price)
    │
    ▼
ReadableProductList { products[], total, pages }
```

### Checkout Flow

```
1. POST /api/v1/cart          → Create/update cart (ShoppingCartApi)
2. POST /api/v1/order/total   → Calculate totals (tax + shipping quotes)
3. POST /api/v1/order/payment → Process payment + create order
    │
    ▼
OrderFacadeImpl.processOrder()
    ├── Validates cart items + inventory
    ├── Calculates OrderTotals via Drools processors
    ├── PaymentService.processPayment()  →  Stripe/PayPal/etc.
    ├── Creates Order entity + OrderProducts
    ├── Decrements ProductAvailability (stock)
    ├── Sends confirmation email (FreeMarker template)
    └── Returns ReadableOrder
```

### Customer Registration & Auth Flow

```
POST /api/v1/customer/register  { email, password, ... }
    │
    ▼
CustomerFacadeImpl.registerCustomer()
    ├── Validates email uniqueness
    ├── BCrypt encodes password
    ├── Creates Customer entity
    └── Sends welcome email

POST /api/v1/customer/login  { username, password }
    │
    ▼
JWTCustomerAuthenticationManager.authenticate()
    ├── Loads CustomerDetails by email
    ├── Validates BCrypt password
    └── Returns JWT token

Authenticated requests:
Authorization: Bearer <token>  →  ROLE_CUSTOMER access
```

### Multi-Store Flow

```
MerchantStore (parent store: "DEFAULT")
    └── child stores (retailers/vendors in marketplace)

Each API request resolves store via:
  - ?store=STORE_CODE query param
  - or X-Store-Code header

Store-scoped data: products, orders, customers, config
Shared data: reference tables (countries, currencies, languages)
```

---

## 12. Configuration & Deployment Profiles

### Spring Profiles

| Profile | Database | Storage | Use Case |
|---------|----------|---------|----------|
| *(default)* | H2 embedded | Local filesystem | Local dev, quick start |
| `local` | MySQL local | Local filesystem | Dev with MySQL |
| `mysql` | MySQL | Local filesystem | Staging |
| `docker` | MySQL (container) | Local filesystem | Docker Compose |
| `gcp` | Cloud SQL (MySQL) | GCP Storage | Google Cloud |
| `cloud` | MySQL (cloud) | AWS S3 or GCP | Generic cloud |
| `aws` | RDS MySQL | AWS S3 | AWS deployment |
| `dependency` | MySQL | Configurable | CI/CD pipelines |

### Key Configuration Files

```
sm-shop/src/main/resources/
├── application.properties          ← Server port, logging, multipart limits
├── shopizer-properties.properties  ← App-level settings
└── profiles/
    └── {profile}/
        └── database.properties     ← DB connection per environment

sm-core/src/main/resources/
└── profiles/
    └── {profile}/
        └── shopizer-core.properties ← Storage, email, search config
```

### Docker Quick Start

```bash
# Backend API
docker run -p 8080:8080 shopizerecomm/shopizer:latest

# Admin UI (requires backend running)
docker run -e "APP_BASE_URL=http://localhost:8080/api" -p 82:80 shopizerecomm/shopizer-admin

# React Storefront (requires backend running)
docker run -e "APP_MERCHANT=DEFAULT" -e "APP_BASE_URL=http://localhost:8080" -p 80:80 shopizerecomm/shopizer-shop-reactjs
```

### Build & Run from Source

```bash
# Build all modules
./mvnw clean install

# Run the app
cd sm-shop
./mvnw spring-boot:run

# API docs available at:
# http://localhost:8080/swagger-ui.html
```

---

## 13. Tech Stack Summary

| Category | Technology | Version |
|----------|-----------|---------|
| Language | Java | 11+ |
| Framework | Spring Boot | 2.5.12 |
| Security | Spring Security + JWT (jjwt) | 0.8.0 |
| Persistence | Spring Data JPA + Hibernate | 5.x |
| Database (dev) | H2 | embedded |
| Database (prod) | MySQL / PostgreSQL / Oracle | 8.0 / 42.x / 18.x |
| Connection Pool | HikariCP | (Spring Boot default) |
| Rules Engine | Drools / KIE | 7.32.0 |
| Cache (local) | EhCache | 2.x |
| Cache (distributed) | Infinispan | 9.4.18 |
| Search | Elasticsearch | 7.5.2 |
| API Docs | Springfox Swagger | 2.9.2 |
| DTO Mapping | MapStruct | 1.3.0 |
| Email Templates | FreeMarker | (Spring Boot managed) |
| File Storage | Local / AWS S3 / GCP Storage | — |
| Payment | Stripe, PayPal, Braintree | 19.5.0 / 2.6.109 / 2.73.0 |
| Geo/IP | MaxMind GeoIP2 | 2.7.0 |
| Build | Maven Wrapper | 3.x |
| CI | CircleCI | — |
| Container | Docker | — |

---

*This document was auto-generated from codebase analysis of the Shopizer repository.*
