# ADS-507 Team 4 – E-Commerce Data Pipeline for Order and Delivery Insights

> **GitHub Repository:** <https://github.com/nikitarogers333/ads507-team4-project>  
> **Course:** ADS-507 Practical Data Engineering  
> **Dataset:** [Brazilian E-Commerce (Olist) – Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

## Team Members

| Name                  | Role                                          |
|-----------------------|-----------------------------------------------|
| Nikita Rogers         | Team Lead – Pipeline orchestration & docs     |
| Jun Sik Ryu           | Data engineering – Schema design & transforms |
| Faye Shawntel Corprew | Data quality – Validation & monitoring        |

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Repository Contents](#repository-contents)
3. [Architecture](#architecture)
4. [Prerequisites](#prerequisites)
5. [Deployment Guide](#deployment-guide)
6. [Running the Pipeline](#running-the-pipeline)
7. [Monitoring the Pipeline](#monitoring-the-pipeline)
8. [Data Schema](#data-schema)
9. [SQL Transformations](#sql-transformations)
10. [Testing](#testing)
11. [Continuous Integration](#continuous-integration)
12. [Troubleshooting](#troubleshooting)

---

## Project Overview

This project implements a production-ready **ETL (Extract-Transform-Load) data pipeline** that processes the Brazilian E-Commerce dataset by Olist. The pipeline:

1. **Extracts** 9 CSV datasets (~100K orders) from a GitHub release
2. **Loads** raw data into MySQL staging tables
3. **Transforms** data using SQL into a star schema (dimensions + facts)
4. **Outputs** 5 analytical views for business intelligence

The entire system is containerized with Docker and can be deployed with a single command.

### Pipeline Output

The pipeline produces five analytical views that provide actionable business insights:

| View | Purpose |
|------|---------|
| `vw_monthly_revenue` | Revenue and order trends by month |
| `vw_delivery_performance` | Delivery speed and late-delivery rates by state |
| `vw_seller_performance` | Seller scoreboard (revenue, ratings, volume) |
| `vw_product_category_performance` | Category-level sales and review analysis |
| `vw_customer_segments` | RFM-style customer segmentation |

---

## Repository Contents

```
.
├── docker-compose.yml              # Infrastructure as Code – all services
├── Makefile                        # Shortcut commands (make up, make test, etc.)
├── .env.example                    # Environment variable template
├── .gitignore
├── .github/
│   └── workflows/
│       └── ci.yml                  # GitHub Actions CI pipeline
├── sql/
│   ├── init/
│   │   └── 001_create_staging.sql  # Staging table definitions (auto-runs on first start)
│   ├── load/
│   │   └── 002_load_data.sql       # LOAD DATA INFILE statements for all CSVs
│   ├── transformations/
│   │   ├── 010_clean_staging.sql   # Data cleaning (trim, nulls, normalisation)
│   │   ├── 020_dim_tables.sql      # Dimension tables (customers, products, sellers, date, geography)
│   │   ├── 030_fact_tables.sql     # Fact tables (orders, items, payments, reviews)
│   │   └── 040_analytical_views.sql# Analytical views for BI output
│   └── validation/
│       └── 050_validate.sql        # Data quality checks
├── scripts/
│   ├── run_pipeline.sh             # Master ETL orchestrator
│   ├── run_transformations.sh      # Re-run transformations only
│   ├── validate.sh                 # Run validation checks
│   ├── monitor.sh                  # Monitoring dashboard
│   └── bootstrap_and_load.sh       # Legacy wrapper
├── tests/
│   └── test_pipeline.sh            # Automated integration tests
├── docs/
│   └── generate_design_doc.py      # Design document generator
└── README.md                       # This file
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Docker Compose Environment                          │
│                                                                             │
│  ┌─────────────┐     ┌──────────────────────────────┐     ┌─────────────┐  │
│  │   GitHub     │     │       Pipeline Container     │     │   Adminer   │  │
│  │   Release    │────▶│       (Alpine Linux)         │     │   (Web GUI) │  │
│  │  (CSV data)  │     │                              │     │  Port 8081  │  │
│  └─────────────┘     │  1. Download CSVs             │     └──────┬──────┘  │
│                       │  2. Load → staging tables     │            │         │
│                       │  3. Clean staging data        │            │         │
│                       │  4. Build dimensions          │            │         │
│                       │  5. Build fact tables          │            │         │
│                       │  6. Create analytical views   │            │         │
│                       │  7. Validate data quality     │            │         │
│                       └──────────────┬───────────────┘            │         │
│                                      │                             │         │
│                                      ▼                             │         │
│                       ┌──────────────────────────────┐            │         │
│                       │     MySQL 8.0 (Port 3306)    │◀───────────┘         │
│                       │                              │                      │
│                       │  ┌─────────┐  ┌───────────┐ │                      │
│                       │  │ Staging │  │ Dimension │ │                      │
│                       │  │ Tables  │  │  Tables   │ │                      │
│                       │  │ (9)     │  │  (5)      │ │                      │
│                       │  └─────────┘  └───────────┘ │                      │
│                       │  ┌─────────┐  ┌───────────┐ │                      │
│                       │  │  Fact   │  │ Analytical│ │                      │
│                       │  │ Tables  │  │   Views   │ │                      │
│                       │  │ (4)     │  │   (5)     │ │                      │
│                       │  └─────────┘  └───────────┘ │                      │
│                       │                              │                      │
│                       │  Volume: mysql_data (persist)│                      │
│                       └──────────────────────────────┘                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
CSV Files (Kaggle Olist)
        │
        ▼
┌─── EXTRACT ──────────────────────────────┐
│  Download from GitHub Release            │
│  Reassemble geolocation (11 parts → 1)   │
│  Convert line endings (dos2unix)         │
└──────────────────────────┬───────────────┘
                           ▼
┌─── LOAD ─────────────────────────────────┐
│  LOAD DATA INFILE → 9 staging tables     │
│  stg_customers, stg_orders, stg_items,  │
│  stg_payments, stg_reviews, stg_products,│
│  stg_sellers, stg_geolocation, stg_cat   │
└──────────────────────────┬───────────────┘
                           ▼
┌─── TRANSFORM ────────────────────────────┐
│  010: Clean staging data                 │
│  020: Build 5 dimension tables           │
│  030: Build 4 fact tables                │
│  040: Create 5 analytical views          │
└──────────────────────────┬───────────────┘
                           ▼
┌─── VALIDATE ─────────────────────────────┐
│  Row counts, null checks, referential    │
│  integrity, business rules               │
└──────────────────────────────────────────┘
```

---

## Prerequisites

- **Docker Desktop** (v20.10+) – [Download](https://docs.docker.com/desktop/)
- **Docker Compose** (v2) – included with Docker Desktop
- **Git** – [Download](https://git-scm.com/downloads)
- **Internet access** – to pull Docker images and download dataset from GitHub release

---

## Deployment Guide

### Step 1: Clone the Repository

```bash
git clone https://github.com/nikitarogers333/ads507-team4-project.git
cd ads507-team4-project
```

### Step 2: Create Environment File

```bash
cp .env.example .env
```

The default values in `.env.example` work out of the box. Edit `.env` if you need to change ports or passwords.

### Step 3: Start the Pipeline

```bash
# Option A – Run everything (recommended for first time)
docker compose up

# Option B – Use Makefile shortcut
make up
```

This single command will:
1. Pull the MySQL 8.0, Alpine 3.19, and Adminer 4 Docker images
2. Start MySQL and wait for it to be healthy
3. Automatically create the 9 staging tables (via init SQL)
4. Start the pipeline container which:
   - Downloads all CSV files from the GitHub release
   - Loads data into staging tables
   - Runs all SQL transformations
   - Validates data quality
5. Start Adminer web GUI on http://localhost:8081

### Step 4: Verify the Pipeline

```bash
# Run automated tests
make test

# Or manually check in Adminer
# Open http://localhost:8081
# Login: Server=mysql, User=root, Password=rootpass507, Database=olist_dw
```

---

## Running the Pipeline

### Full Pipeline (first time or reset)

```bash
# Start everything from scratch
make clean    # Remove all data
make up       # Run full pipeline
```

### Re-run Transformations Only

If staging data is already loaded and you want to rebuild dimension/fact tables:

```bash
docker compose run --rm pipeline sh /scripts/run_transformations.sh
```

### Re-run Validation Only

```bash
docker compose run --rm pipeline sh /scripts/validate.sh
```

### Stop the System

```bash
make down     # Stop containers (data persists)
make clean    # Stop and remove all data
```

---

## Monitoring the Pipeline

### 1. Real-time Pipeline Logs

```bash
# Follow the pipeline output as it runs
docker compose logs -f pipeline

# Or use Makefile
make logs
```

### 2. Monitoring Dashboard

```bash
docker compose run --rm pipeline sh /scripts/monitor.sh
```

This displays:
- Database connection status
- Table row counts and sizes
- Pipeline completion status (staging/dim/fact/view counts)
- Latest pipeline log excerpt
- Active MySQL processes

### 3. Adminer Web GUI

Open **http://localhost:8081** in your browser.

| Field    | Value         |
|----------|---------------|
| System   | MySQL         |
| Server   | mysql         |
| Username | root          |
| Password | rootpass507    |
| Database | olist_dw      |

From Adminer you can:
- Browse all tables and views
- Run ad-hoc SQL queries
- Export data as CSV/SQL
- View table structures and relationships

### 4. Pipeline Log Files

Pipeline runs are logged to `/logs/pipeline_YYYYMMDD_HHMMSS.log` inside the pipeline container. View the latest log:

```bash
docker compose run --rm pipeline sh -c 'cat $(ls -t /logs/pipeline_*.log | head -1)'
```

### 5. Container Status

```bash
make status
# or
docker compose ps
```

---

## Data Schema

### Staging Tables (Raw Data)

| Table | Description | ~Rows |
|-------|-------------|-------|
| `stg_customers` | Customer profiles | 99,441 |
| `stg_orders` | Order headers | 99,441 |
| `stg_order_items` | Line items per order | 112,650 |
| `stg_order_payments` | Payment records | 103,886 |
| `stg_order_reviews` | Customer reviews | 99,224 |
| `stg_products` | Product catalog | 32,951 |
| `stg_sellers` | Seller profiles | 3,095 |
| `stg_geolocation` | Zip code coordinates | ~1M |
| `stg_category_translation` | Portuguese → English | 71 |

### Dimension Tables (Star Schema)

| Table | Description | Key |
|-------|-------------|-----|
| `dim_customers` | Deduplicated customers | `customer_key` |
| `dim_products` | Products with English categories | `product_key` |
| `dim_sellers` | Seller profiles | `seller_key` |
| `dim_date` | Calendar (2016–2018) | `date_key` (YYYYMMDD) |
| `dim_geography` | Avg lat/lng per zip code | `geo_key` |

### Fact Tables (Metrics)

| Table | Description | Key Metrics |
|-------|-------------|-------------|
| `fact_orders` | One row per order | total_amount, delivery_days, is_late |
| `fact_order_items` | One row per line item | price, freight_value |
| `fact_payments` | One row per payment line | payment_value, installments |
| `fact_reviews` | One row per review | review_score |

---

## SQL Transformations

The pipeline runs 4 transformation scripts in order:

### 1. `010_clean_staging.sql` – Data Cleaning
- Trims whitespace from string columns
- Normalises empty strings to NULL
- Standardises state codes to uppercase
- Normalises category names to lowercase

### 2. `020_dim_tables.sql` – Dimension Tables
- **dim_customers** – Direct load from staging
- **dim_products** – Joined with category translation for English names
- **dim_sellers** – Direct load from staging
- **dim_date** – Generated via recursive CTE (2016-01-01 to 2018-12-31)
- **dim_geography** – Aggregated from geolocation (avg lat/lng per zip)

### 3. `030_fact_tables.sql` – Fact Tables
- **fact_orders** – Enriched with aggregated item totals, payment totals, and delivery performance metrics (actual vs. estimated days, late delivery flag)
- **fact_order_items** – Linked to product and seller dimension keys
- **fact_payments** – Direct load from staging
- **fact_reviews** – Direct load from staging

### 4. `040_analytical_views.sql` – Business Intelligence Views
- Monthly revenue trends
- Delivery performance by state
- Seller performance scoreboard
- Product category analysis
- Customer segmentation (one-time / returning / loyal)

---

## Testing

### Run Integration Tests

```bash
make test
# or
bash tests/test_pipeline.sh
```

The test suite checks:
- MySQL container health
- All 9 staging tables have data
- All 5 dimension tables have data
- All 4 fact tables have data
- All 5 analytical views return results
- Referential integrity (no orphan foreign keys)
- Business rules (no negative payments, review scores 1–5)

### Expected Output

```
=============================================
  ADS-507 Pipeline – Integration Tests
=============================================

── Container Health ─────────────────────────
  PASS MySQL container is running

── Staging Tables ───────────────────────────
  PASS stg_customers has rows (got: 99441)
  PASS stg_orders has rows (got: 99441)
  ...

── Results: 27 passed, 0 failed, 27 total
=============================================
```

---

## Continuous Integration

GitHub Actions runs on every push and pull request to `main`:

1. **Lint & Validate** – Checks Docker Compose config, SQL syntax, shell scripts (ShellCheck)
2. **Docker Build Test** – Starts MySQL, verifies all 9 staging tables are created

View CI status on the [Actions tab](https://github.com/nikitarogers333/ads507-team4-project/actions).

---

## Troubleshooting

### "Port 3306 is already in use"

Change the port in `.env`:
```bash
MYSQL_PORT=3307
```

### Pipeline fails to download data

Check internet connectivity and that the GitHub release exists:
```bash
curl -I https://github.com/nikitarogers333/ads507-team4-project/releases/tag/v1.0-raw-data
```

### "Table doesn't exist" errors

The staging tables are created on MySQL's first start. If the volume already exists from a previous run with different SQL, reset everything:
```bash
make clean    # Removes volumes
make up       # Fresh start
```

### Adminer can't connect

Ensure Adminer is using `mysql` as the server hostname (not `localhost`), and the password matches your `.env` file.

---

## References

- Olist. (2018). *Brazilian E-Commerce Public Dataset by Olist* [Dataset]. Kaggle. https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
- Docker Inc. (2024). *Docker Compose documentation*. https://docs.docker.com/compose/
- Oracle Corporation. (2024). *MySQL 8.0 Reference Manual*. https://dev.mysql.com/doc/refman/8.0/en/

---

*ADS-507 Practical Data Engineering – University of San Diego – Spring 2026*
