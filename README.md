# Command Center Dashboard

A modern, interactive Salesforce Lightning Web Component dashboard for portfolio management and deal tracking. Built with Chart.js integration, real-time filtering, and CRM Analytics-inspired design.

![Command Center Dashboard](docs/images/dashboard-preview.png)

## Features

### Interactive Data Visualization
- **Bar Charts** - Vertical and horizontal chart views with smooth animations
- **Priority Series Filtering** - Filter by D500, D600, D700 deal series
- **Status Filtering** - Multi-select status chips with color coding
- **Priority Code Drilldown** - Click chart bars to filter by specific priority codes

### KPI Summary Row
- **Record Count** - Total accounts in current view
- **Total Revenue** - Aggregated revenue figures
- **Toggle Display Mode** - Switch between count and revenue views

### Data Tables
- **Status Distribution** - Breakdown by target status with counts and revenue
- **Account Details** - Detailed account information with sorting and pagination
- **Click-to-Navigate** - Direct links to Salesforce records

### Design
- Clean, professional CRM Analytics-inspired styling
- Responsive layout for desktop and mobile
- Shimmer loading states
- Smooth transitions and animations

## Architecture

```
commandCenterContainer (Parent)
├── commandCenterHeader
├── commandCenterKpiRow
├── commandCenterFilterBar
├── commandCenterChart
├── commandCenterStatusTable
├── commandCenterAccountTable
└── commandCenterFooter
```

### Component Communication
- **Lightning Message Service** - Cross-component filter synchronization via `DashboardFilterChannel`
- **Custom Events** - Parent-child communication for display mode and priority selection
- **Reactive Properties** - Real-time UI updates via `@api` decorated properties

## Installation

See [INSTALL.md](INSTALL.md) for detailed deployment instructions.

### Quick Start

```bash
# Clone the repository
git clone https://github.com/your-org/command-center-dashboard.git
cd command-center-dashboard

# Authenticate to your org
sf org login web -a MyOrg

# Deploy to your org
sf project deploy start -o MyOrg
```

## Requirements

- Salesforce org with Lightning Experience enabled
- API version 65.0 or higher
- Custom objects (see Installation Guide):
  - `Account` with custom fields
  - `Cadence_Priority_Code__c`
  - `Target__c`

## Project Structure

```
force-app/
└── main/
    └── default/
        ├── classes/
        │   ├── DashboardController.cls      # Main data controller
        │   ├── DashboardControllerTest.cls  # Test coverage
        │   ├── DealMetricsImporter.cls      # Data import utility
        │   └── DealMetricsImportBatch.cls   # Batch processing
        ├── lwc/
        │   ├── commandCenterContainer/      # Main container
        │   ├── commandCenterHeader/         # Dashboard header
        │   ├── commandCenterKpiRow/         # KPI summary cards
        │   ├── commandCenterFilterBar/      # Filter controls
        │   ├── commandCenterChart/          # Chart.js visualization
        │   ├── commandCenterStatusTable/    # Status breakdown table
        │   ├── commandCenterAccountTable/   # Account details table
        │   └── commandCenterFooter/         # Dashboard footer
        └── messageChannels/
            └── DashboardFilterChannel/      # LMS channel
```

## Configuration

### Adding to Lightning App Builder

1. Navigate to **Setup > Lightning App Builder**
2. Create or edit a Lightning Page
3. Drag `commandCenterContainer` onto the page
4. Save and activate

### Customizing Priority Series

Edit the priority series definitions in `commandCenterFilterBar.js`:

```javascript
prioritySeries = [
    { value: '500', label: 'D500', color: '#3b82f6' },
    { value: '600', label: 'D600', color: '#a855f7' },
    { value: '700', label: 'D700', color: '#ef4444' }
];
```

## Development

### Local Development Server

```bash
sf lightning dev app -o YourOrg
```

### Running Tests

```bash
# Apex tests
sf apex run test -n DashboardControllerTest -o YourOrg -r human

# LWC Jest tests
npm test
```

### Code Quality

```bash
# Lint
npm run lint

# Format
npm run prettier
```

## API Reference

### DashboardController

| Method | Description | Returns |
|--------|-------------|---------|
| `getDashboardData()` | Fetches all dashboard data | `DashboardData` wrapper |
| `getAccountsByPriorityCode(String code)` | Gets accounts for priority code | `List<Account>` |

### Events

| Event | Description | Detail |
|-------|-------------|--------|
| `displaymodechange` | Toggle count/revenue view | `{ mode: 'count' \| 'revenue' }` |
| `barclick` | Chart bar clicked | `{ priorityCode: String }` |
| `prioritycodeclick` | Filter chip clicked | `{ code: String }` |

## License

Copyright (c) 2024 Revelate Operations. All rights reserved.

See [LICENSE](LICENSE) for details.

## Support

For support, contact [support@revelateops.com](mailto:support@revelateops.com)

---

Built with care by [Revelate Operations](https://revelateops.com)
