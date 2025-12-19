# Architecture Overview

This document describes the technical architecture of the Command Center Dashboard.

## Component Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                    commandCenterContainer                        │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                  commandCenterHeader                        │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                  commandCenterKpiRow                        │ │
│  │  ┌──────────────────┐  ┌──────────────────┐                │ │
│  │  │   Record Count   │  │   Total Revenue  │                │ │
│  │  └──────────────────┘  └──────────────────┘                │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                 commandCenterFilterBar                      │ │
│  │  [D500] [D600] [D700]  |  Status Chips  |  Priority Codes  │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────┐  ┌──────────────────────────────┐ │
│  │   commandCenterChart    │  │  commandCenterStatusTable    │ │
│  │   ┌─────────────────┐   │  │  ┌────────────────────────┐  │ │
│  │   │    Chart.js     │   │  │  │   Status Breakdown     │  │ │
│  │   │    Bar Chart    │   │  │  │   with Revenue         │  │ │
│  │   └─────────────────┘   │  │  └────────────────────────┘  │ │
│  └─────────────────────────┘  └──────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                commandCenterAccountTable                    │ │
│  │  Account details with sorting, pagination, navigation      │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                  commandCenterFooter                        │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Initial Load

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  Container      │────▶│  DashboardController │────▶│  Salesforce     │
│  connectedCb    │     │  getDashboardData()  │     │  Database       │
└─────────────────┘     └──────────────────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐
│  @wire results  │
│  dashboardData  │
└─────────────────┘
         │
         ├──────────────────────────────────────────────┐
         │                                              │
         ▼                                              ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  kpiData        │     │  chartData      │     │  tableData      │
│  (computed)     │     │  (computed)     │     │  (computed)     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                      │                       │
         ▼                      ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  KpiRow         │     │  Chart          │     │  Tables         │
│  Component      │     │  Component      │     │  Components     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Filter Communication

The dashboard uses **Lightning Message Service (LMS)** for cross-component communication:

```
┌─────────────────┐                    ┌─────────────────┐
│  FilterBar      │                    │  Container      │
│                 │    LMS Publish     │                 │
│  User clicks    │───────────────────▶│  @wire          │
│  filter chip    │                    │  subscription   │
└─────────────────┘                    └─────────────────┘
                                               │
                     DashboardFilterChannel    │
                     ┌─────────────────────────┤
                     │                         │
                     ▼                         ▼
              ┌─────────────────┐     ┌─────────────────┐
              │  Update         │     │  Re-compute     │
              │  filterState    │     │  filtered data  │
              └─────────────────┘     └─────────────────┘
```

### Event Flow (Parent-Child)

Custom events bubble up from child components:

```
Chart Click Event:
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Chart Canvas   │────▶│  Chart.js       │────▶│  LWC Handler    │
│  onClick        │     │  onClick        │     │  handleChartClick│
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │  CustomEvent    │
                                               │  'barclick'     │
                                               │  bubbles: true  │
                                               └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │  Container      │
                                               │  onbarclick     │
                                               └─────────────────┘
```

## State Management

### Container State

```javascript
// Filter state (persisted)
filterState = {
    prioritySeries: [],      // ['500', '600']
    targetStatuses: [],      // ['Active', 'Pending']
    priorityCode: null       // '501' or null
}

// Display state
displayMode = 'count'        // 'count' | 'revenue'

// Data state (from wire)
dashboardData = {
    totalAccounts: Number,
    totalAssets: Number,
    cadenceMatrixData: [...],
    targetUniverseData: [...],
    accountData: [...]
}
```

### Computed Properties

Data flows through computed getters that apply filters:

```javascript
get chartData() {
    // Apply prioritySeries filter to cadenceMatrixData
    return filtered and transformed data
}

get kpiData() {
    // Aggregate from filtered data
    return { totalAccounts, totalAssets }
}

get statusTableData() {
    // Apply filters to targetUniverseData
    return filtered status breakdown
}
```

## Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| `Container` | Data fetching, state management, filter coordination |
| `Header` | Branding, title display |
| `KpiRow` | KPI display, display mode toggle |
| `FilterBar` | All filter UI controls |
| `Chart` | Chart.js rendering, bar click handling |
| `StatusTable` | Status breakdown display |
| `AccountTable` | Account list with pagination |
| `Footer` | Footer content |

## External Dependencies

### Chart.js

- Version: 4.x
- Loaded via Static Resource
- Used for bar chart visualization
- Configured in `commandCenterChart.js`

### Lightning Message Service

- Channel: `DashboardFilterChannel__c`
- Used for: Filter state synchronization
- Subscribers: Container, FilterBar

## Performance Considerations

### Data Loading
- Single Apex call fetches all data upfront
- Computed properties filter client-side (no re-fetch)
- Wire adapter caches results

### Rendering
- LWC reactive system handles efficient DOM updates
- Chart.js updates via `chart.update()` (not full re-render)
- Shimmer states prevent layout shift

### Memory
- Chart instance destroyed in `disconnectedCallback`
- Message channel subscription cleaned up automatically
