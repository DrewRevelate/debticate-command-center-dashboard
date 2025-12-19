# Changelog

All notable changes to the Command Center Dashboard will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-18

### Added
- Initial release of Command Center Dashboard
- **commandCenterContainer** - Main dashboard container with data orchestration
- **commandCenterHeader** - Dashboard header with branding
- **commandCenterKpiRow** - KPI summary cards (Record Count, Total Revenue)
- **commandCenterFilterBar** - Interactive filter controls
  - Priority series toggle (D500, D600, D700)
  - Status filter chips with color coding
  - Priority code quick filters
- **commandCenterChart** - Interactive Chart.js visualization
  - Vertical and horizontal bar chart modes
  - Click-to-filter functionality
  - Responsive canvas sizing
- **commandCenterStatusTable** - Status breakdown with counts and revenue
- **commandCenterAccountTable** - Detailed account listing with pagination
- **commandCenterFooter** - Dashboard footer

### Features
- Lightning Message Service integration for cross-component communication
- Display mode toggle (count vs. revenue)
- Real-time filter synchronization
- Shimmer loading states
- Responsive design for desktop and mobile
- CRM Analytics-inspired visual design

### Technical
- Chart.js 4.x integration via static resource
- Apex controller with SOQL aggregation
- 100% Apex test coverage
- LWC best practices (reactive properties, event bubbling)

## [Unreleased]

### Planned
- Export to CSV functionality
- Date range filtering
- Saved filter presets
- Dark mode support
