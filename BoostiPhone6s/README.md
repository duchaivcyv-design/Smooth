### Extended iOS-to-Backend Architecture

> **Architecture simulation:** This diagram illustrates a proposed integration model. Apple system components and external Apple services are not assumed to forward requests to the project backend. Only supported, explicitly configured integrations should be enabled.

```mermaid
flowchart TB

    subgraph IOS["LAYER 1 — iOS SYSTEM"]
        A01["01 · Server Apple
        A02["02 · iOS Runtime"]
        A03["03 · System Frameworks"]
        A04["04 · Application / Tweak Host"]
        A05["05 · Tweak Runtime"]
        A06["06 · Local Preferences"]
        A06["07 · RootListController"]
        A01 --> A02 --> A03 --> A04 --> A05 --> A06 --> A07
    end

    subgraph FEATURES["LAYER 2 — FEATURE ROUTING"]
        B07["07 · Feature Dispatcher"]
        B08["08 · Home"]
        B09["09 · Hz / FPS"]
        B10["10 · Switch"]
        B11["11 · Apps"]
        B12["12 · Settings"]
        B13["13 · Admin"]
        B14["14 · Admin Dev"]
        A06 --> B07
        B07 --> B08
        B07 --> B09
        B07 --> B10
        B07 --> B11
        B07 --> B12
        B07 --> B13
        B07 --> B14
    end

    subgraph CLIENT["LAYER 3 — CLIENT REQUEST PIPELINE"]
        C15["15 · API Client"]
        C16["16 · Endpoint Configuration"]
        C17["17 · Request Builder"]
        C18["18 · Input Validation"]
        C19["19 · Session Credential"]
        C20["20 · iOS Network Stack"]
        C21["21 · DNS Resolution"]
        C22["22 · TLS Certificate Validation"]
        B08 --> C15
        B09 --> C15
        B10 --> C15
        B11 --> C15
        B12 --> C15
        B13 --> C15
        B14 --> C15
        C15 --> C16 --> C17 --> C18 --> C19 --> C20 --> C21 --> C22
    end

    subgraph EXTERNAL["LAYER 4 — EXTERNAL SERVICE BOUNDARY"]
        D23["23 · Optional Apple Service Integration"]
        D24["24 · Supported Apple API"]
        D25["25 · External Response Validation"]
        D23 --> D24 --> D25
    end

    subgraph GATEWAY["LAYER 5 — PROJECT GATEWAY"]
        E26["26 · Project HTTPS Endpoint"]
        E27["27 · Public Network Boundary"]
        E28["28 · Reverse Proxy"]
        E29["29 · TLS / Connection Policy"]
        E30["30 · Request Limits"]
        C22 --> E26 --> E27 --> E28 --> E29 --> E30
    end

    subgraph SECURITY["LAYER 6 — BACKEND SECURITY"]
        F31["31 · Express Application"]
        F32["32 · HTTP Request Validation"]
        F33["33 · Authentication Middleware"]
        F34["34 · Session Verification"]
        F35["35 · Role-Based Authorization"]
        E30 --> F31 --> F32 --> F33 --> F34 --> F35
    end

    subgraph SERVICES["LAYER 7 — APPLICATION SERVICES"]
        G36["36 · Application Service Router"]
        G37["37 · Device Monitoring"]
        G38["38 · Account / Session Management"]
        G39["39 · Blacklist / Violation Policies"]
        G40["40 · Admin Dev Operations"]
        G41["41 · Audit Logging"]
        F35 --> G36
        G36 --> G37
        G36 --> G38
        G36 --> G39
        G36 --> G40
        G36 --> G41
    end

    subgraph STORAGE["LAYER 8 — PERSISTENCE"]
        H42["42 · Data Access Layer"]
        H43[("43 · SQLite Database")]
        H44["44 · Protected Backup / Recovery"]
        G37 --> H42
        G38 --> H42
        G39 --> H42
        G40 --> H42
        G41 --> H42
        H42 --> H43
        H43 --> H44
    end

    subgraph RESPONSE["LAYER 9 — RESPONSE PATH"]
        I45["45 · Result Mapping"]
        I46["46 · Error Handling"]
        I47["47 · HTTP Response"]
        I48["48 · Client Response Validation"]
        I49["49 · UI State Update"]
        I50["50 · Feature Refresh"]
        H42 -. "Operation result" .-> I45
        D25 -. "Optional external result" .-> I45
        I45 --> I46 --> I47 --> I48 --> I49 --> I50
        I50 -. "Updated state" .-> A06
    end

    classDef ios fill:#263b59,stroke:#78a6e8,color:#ffffff
    classDef feature fill:#283d32,stroke:#6fba8c,color:#ffffff
    classDef network fill:#3b344d,stroke:#b19ae8,color:#ffffff
    classDef security fill:#4a3035,stroke:#e78c98,color:#ffffff
    classDef storage fill:#263d42,stroke:#7cc6ce,color:#ffffff

    class A01,A02,A03,A04,A05,A06 ios
    class B07,B08,B09,B10,B11,B12,B13,B14,I49,I50 feature
    class C15,C16,C17,C18,C19,C20,C21,C22,D23,D24,D25,E26,E27,E28,E29,E30 network
    class F31,F32,F33,F34,F35,G36,G37,G38,G39,G40,G41,I45,I46,I47,I48 security
    class H42,H43,H44 storage
```

### Connection Groups

| Group                | Points | Purpose                                                        |
| -------------------- | -----: | -------------------------------------------------------------- |
| iOS System           |  01–06 | Runtime, supported frameworks, local configuration             |
| Feature Routing      |  07–14 | Main interface and administrative sections                     |
| Client Pipeline      |  15–22 | Request construction, endpoint selection, DNS and TLS          |
| External Integration |  23–25 | Optional supported Apple API integration                       |
| Project Gateway      |  26–30 | Public endpoint, reverse proxy and request limits              |
| Backend Security     |  31–35 | Request validation, authentication, sessions and authorization |
| Application Services |  36–41 | Monitoring, account administration, restrictions and audit     |
| Persistence          |  42–44 | Data access, database, backup and recovery                     |
| Response Path        |  45–50 | Result handling, HTTP response and client UI refresh           |

### Trust Boundaries

1. **iOS to network:** client input and local state are untrusted.
2. **Network to gateway:** requests must use the configured HTTPS endpoint.
3. **Gateway to backend:** only approved traffic should reach the application.
4. **Backend authentication:** credentials and sessions must be validated.
5. **Backend authorization:** every privileged operation must verify permissions.
6. **Backend to database:** access must use controlled application code and parameterized queries.
7. **External service integration:** Apple API access must use supported endpoints and valid authorization.
8. **Response to client:** responses must be validated and must not be treated as successful solely because a connection was established.

### Integration Status

* **iOS system layer:** depends on the actual tweak runtime and supported iOS APIs.
* **Feature routing:** depends on the implementation of `RootListController.m` and the feature handlers.
* **Project gateway:** requires a real configured endpoint and deployment.
* **Authentication and Admin Dev:** require implemented backend routes and server-side permission checks.
* **Apple service integration:** optional; inactive unless a supported API and valid credentials are configured.
* **Database and backup:** depend on the actual backend schema and deployment configuration.
* **Response path:** depends on the client's request and error-handling implementation.

This extended diagram is an architectural model, not evidence that every numbered component is already connected or operational.
