# PetVision AI: System Architecture

This document outlines the complete, end-to-end architecture of the PetVision AI application, from the Flutter mobile frontend down to the database persistence layer.

## High-Level System Architecture

```mermaid
graph TD
    %% Styling
    classDef frontend fill:#02569B,stroke:#fff,stroke-width:2px,color:#fff;
    classDef proxy fill:#f39c12,stroke:#fff,stroke-width:2px,color:#fff;
    classDef backend fill:#009688,stroke:#fff,stroke-width:2px,color:#fff;
    classDef core fill:#E91E63,stroke:#fff,stroke-width:2px,color:#fff;
    classDef data fill:#336791,stroke:#fff,stroke-width:2px,color:#fff;
    classDef storage fill:#C72228,stroke:#fff,stroke-width:2px,color:#fff;

    %% Subgraphs
    subgraph "Client Tier (Mobile)"
        FlutterApp["📱 Flutter App<br/>(Riverpod 3, Camera, WebSockets)"]:::frontend
    end

    subgraph "API Gateway / Auth"
        Auth["🔐 Auth Service<br/>(Firebase/JWT Mock)"]:::proxy
        Router["🌐 FastAPI Router<br/>(Endpoints, Security, Limits)"]:::backend
    end

    subgraph "Core AI Services (FastAPI)"
        WS["⚡ WebSocket Manager<br/>(Real-time State Sync)"]:::core
        CV["🧠 YOLOv8 Inference Pipeline<br/>(PyTorch CV Analysis)"]:::core
        LLM["🤖 LLM Vet Synthesis<br/>(OpenAI/Local Reporting)"]:::core
        Trends["📈 Longitudinal Engine<br/>(30-Day Moving Averages)"]:::core
        Billing["💳 Subscription Limits<br/>(3 Scans/Mo Enforcer)"]:::core
    end

    subgraph "Data & Persistence Layer"
        TimescaleDB[("🐘 TimescaleDB / PostgreSQL<br/>(Profiles & Timeseries Scans)")]:::data
        MinIO[("🪣 MinIO S3<br/>(Raw Image Storage)")]:::storage
        Redis[("⚡ Redis<br/>(Optional Caching)")]:::data
    end

    %% Flow Paths
    FlutterApp -- "1. Uploads Burst (REST POST)" --> Router
    FlutterApp -- "2. Subscribes to Status" --> WS
    
    Router -- "Validates User" --> Auth
    Router -- "Validates Limits" --> Billing
    
    Router -- "Pipes Media" --> MinIO
    Router -- "Hands Bytes" --> CV
    
    CV -- "Analyzes Frame" --> CV
    CV -- "Returns Scores" --> Router
    
    Router -- "Persists Profile/Metrics" --> TimescaleDB
    Router -- "Pushes Step-by-Step Status" --> WS

    FlutterApp -- "Requests Trends" --> Trends
    Trends -- "Aggregates Historic Data" --> TimescaleDB
    
    FlutterApp -- "Requests Vet Report" --> LLM
    LLM -- "Reads Trends" --> Trends
```

### Component Breakdown

1. **📱 Flutter Mobile App**: The primary user interface. Handles local camera feed, buffers 10-second image bursts, caches offline scans for batch uploading, and visualizes analytical charts utilizing Riverpod for state management.
2. **🌐 FastAPI Backend**: The high-performance Python server. It coordinates API routing dynamically using clean dependency injection.
3. **🔐 Auth & Billing**: Protects the API. Assigns scans safely to specific user UUIDs and limits raw pipeline execution cleanly (e.g., maximum 3 free scans per month).
4. **🧠 YOLOv8 Computer Vision Pipeline**: The core intelligence. Loaded in Python via PyTorch, it evaluates raw bytes sequentially for body condition, eye health, dental plaque, and coat traits, computing numeric scores accurately.
5. **⚡ WebSocket Manager**: Because ML operations take time, the router streams exact inference phases ("Ingesting -> Processing -> Saved") cleanly back to Flutter instances asynchronously without blocking them.
6. **🐘 TimescaleDB**: A powerful PostgreSQL extension optimized purely for time-series data. It makes querying vast arrays of historical `PetScanResult` entries for the `Longitudinal Engine` hyper-efficient.
7. **🪣 MinIO S3**: S3-compatible object storage. Securely harbors the raw jpeg images locally, freeing the SQL database structurally to index URLs rather than massive blobs of byte data.
