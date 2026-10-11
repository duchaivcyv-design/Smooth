## System Architecture — Apple-to-Backend Integration Flow

> **Architecture model — not an official Apple infrastructure diagram.** This diagram illustrates the conceptual path from the iOS device and optional Apple service integration to the project's own backend. Actual Apple services, intermediate providers, and network hops depend on the supported APIs and deployment configuration.

### 1. Full Connection Flow

```mermaid
flowchart TD

    A["01 · iPhone / iOS Device"]
    B["02 · iOS System Frameworks"]
    C["03 · App or Tweak Runtime"]
    D["04 · Local Configuration"]
    E["05 · API Request Preparation"]

    A --> B --> C --> D --> E

    subgraph APPLE["APPLE SERVICES — ONLY WHEN SUPPORTED AND CONFIGURED"]
        F["06 · Apple Service Entry Point"]
        G["07 · Apple Authentication / Authorization"]
        H["08 · Apple Service API"]
        I["09 · Apple Service Response"]
        F --> G --> H --> I
    end

    E -. "Optional Apple API request" .-> F
    I -. "Optional service response" .-> E

    subgraph CLIENT_NETWORK["CLIENT NETWORK PATH"]
        J["10 · iOS Network Stack"]
        K["11 · DNS Resolver"]
        L["12 · TLS Certificate Verification"]
        M["13 · Configured Project HTTPS Hostname"]
        J --> K --> L --> M
    end

    E --> J

    subgraph EDGE["PROJECT NETWORK EDGE"]
        N["14 · Public Network Boundary"]
        O["15 · CDN / Edge Proxy — if configured"]
        P["16 · Reverse Proxy / Load Balancer — if configured"]
        Q["17 · Firewall and Ingress Rules"]
        R["18 · Request Routing"]
        N --> O --> P --> Q --> R
    end

    M --> N

    subgraph BACKEND["PROJECT BACKEND"]
        S["19 · Node.js Runtime"]
        T["20 · Express Application"]
        U["21 · HTTP Method and Payload Validation"]
        V["22 · Authentication Middleware"]
        W["23 · Session Validation"]
        X["24 · Role and Permission Checks"]
        Y["25 · Application Service Router"]

        S --> T --> U --> V --> W --> X --> Y
    end

    R --> S

    subgraph SERVICES["APPLICATION SERVICES"]
        Z["26 · Login / Authentication Service"]
        AA["27 · Device Monitoring Service"]
        AB["28 · Account and Session Management"]
        AC["29 · Blacklist Service"]
        AD["30 · Violation Policy Service"]
        AE["31 · Admin Dev Service"]
        AF["32 · Audit Logging Service"]

        Y --> Z
        Y --> AA
        Y --> AB
        Y --> AC
        Y --> AD
        Y --> AE
        Y --> AF
    end

    subgraph DATA["PERSISTENCE AND OPERATIONS"]
        AG["33 · Data Access Layer"]
        AH[("34 · SQLite Database")]
        AI["35 · Backup and Recovery"]
        AJ["36 · Security Event Records"]

        Z --> AG
        AA --> AG
        AB --> AG
        AC --> AG
        AD --> AG
        AE --> AG
        AF --> AG
        AG --> AH
        AH --> AI
        AF --> AJ
    end

    subgraph RESPONSE["RESPONSE PATH"]
        AK["37 · Service Result"]
        AL["38 · HTTP Status and Response Body"]
        AM["39 · Client Response Validation"]
        AN["40 · UI State Update"]

        AK --> AL --> AM --> AN
    end

    AG -. "Result" .-> AK
    AN -. "Display updated result" .-> D
```

### 2. What Each Server Layer Does

| Stage | Layer                   | Purpose                                                                             |
| ----: | ----------------------- | ----------------------------------------------------------------------------------- |
| 01–05 | iOS client              | Runs the supported client code and prepares requests.                               |
| 06–09 | Optional Apple services | Handles only the Apple APIs explicitly supported and configured by the project.     |
| 10–13 | Client networking       | Resolves the configured hostname and establishes a validated HTTPS connection.      |
| 14–18 | Network edge            | Optionally filters, proxies, and routes incoming traffic.                           |
| 19–25 | Backend security        | Receives requests, validates input, authenticates sessions, and checks permissions. |
| 26–32 | Application services    | Handles login, monitoring, sessions, restrictions, Admin Dev, and auditing.         |
| 33–36 | Persistence             | Stores records and supports backup and security operations.                         |
| 37–40 | Response path           | Returns the operation result to the client and updates the interface.               |

### 3. Important Connection Rules

* Apple services and the project backend are separate trust domains.
* The project backend receives requests only when the client or an authorized integration actually sends them to the configured project endpoint.
* A CDN, load balancer, or reverse proxy is present only if deployed.
* Authentication and role checks must be enforced by the backend, not just by the interface.
* The database should not be directly exposed to the public network.
* Apple authentication does not automatically authenticate a user to the project's own backend.
* A successful TLS connection does not mean the requested operation is authorized.
* Error responses must not be treated as successful operations.

### 4. Actual Deployment Versus Conceptual Architecture

The diagram is a **proposed integration model**. Before describing any component as active, verify the actual hostname, supported Apple API, proxy configuration, backend route, authentication policy, and database implementation.

Do not label a privately operated server as an official Apple server. A project-controlled gateway can use a neutral name such as `Service Gateway` or `Apple API Integration Gateway` when it genuinely connects to a supported Apple API, provided the documentation clearly identifies the project as independent.
