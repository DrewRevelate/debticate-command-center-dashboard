# Installation Guide

This guide walks you through deploying the Command Center Dashboard to your Salesforce org.

## Prerequisites

### Required Tools

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (v2.0 or higher)
- [Node.js](https://nodejs.org/) (v18 or higher)
- Git

### Org Requirements

- Salesforce org with Lightning Experience enabled
- System Administrator or equivalent permissions
- My Domain enabled and deployed

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/command-center-dashboard.git
cd command-center-dashboard
```

### 2. Authenticate to Your Org

For production or Developer Edition:
```bash
sf org login web -a MyOrg
```

For sandbox:
```bash
sf org login web -a MyOrg -r https://test.salesforce.com
```

### 3. Deploy the Package

#### Full Deployment
```bash
sf project deploy start -o MyOrg --wait 10
```

#### Deploy Specific Components
```bash
# Deploy only the LWC components
sf project deploy start \
  --source-dir force-app/main/default/lwc \
  --source-dir force-app/main/default/classes \
  --source-dir force-app/main/default/messageChannels \
  -o MyOrg --wait 10
```

### 4. Verify Deployment

```bash
sf project deploy report -o MyOrg
```

### 5. Run Tests

```bash
sf apex run test -n DashboardControllerTest -o MyOrg -r human -c
```

## Post-Installation Configuration

### Add to Lightning Page

1. Navigate to **Setup** > **Lightning App Builder**
2. Click **New** to create a new Lightning Page (or edit existing)
3. Select **App Page** and click **Next**
4. Enter a label (e.g., "Command Center") and choose a layout
5. From the Components panel, find **commandCenterContainer**
6. Drag it onto your page canvas
7. Click **Save**
8. Click **Activation** and activate for your desired apps/profiles
9. Click **Save**

### Assign Permissions

Ensure users have access to:
- The Apex class `DashboardController`
- The custom objects used by the dashboard
- The Lightning page where the component is placed

## Custom Object Requirements

The dashboard expects the following objects and fields:

### Account (Standard Object)
| Field API Name | Type | Description |
|---------------|------|-------------|
| `Name` | Text | Account name |
| `Total_Assets_Under_Management__c` | Currency | Revenue amount |
| `Priority_Code__c` | Picklist/Text | Priority classification |
| `Target_Status__c` | Picklist | Current status |

### Cadence_Priority_Code__c (Custom Object)
| Field API Name | Type | Description |
|---------------|------|-------------|
| `Name` | Text | Priority code (e.g., "501", "602") |
| `Priority_Series__c` | Text | Series grouping (500, 600, 700) |
| `Color__c` | Text | Hex color code |
| `Description__c` | Text | Code description |

### Target__c (Custom Object)
| Field API Name | Type | Description |
|---------------|------|-------------|
| `Name` | Text | Target name |
| `Status__c` | Picklist | Target status |
| `Account__c` | Lookup | Related account |

## Troubleshooting

### Deployment Fails: "Unable to find Apex action class"

Ensure `DashboardController.cls` is deployed before the LWC components:
```bash
sf project deploy start --source-dir force-app/main/default/classes -o MyOrg
sf project deploy start --source-dir force-app/main/default/lwc -o MyOrg
```

### Component Not Visible in App Builder

1. Verify the component's `*.js-meta.xml` has `isExposed` set to `true`
2. Ensure the target is set correctly:
```xml
<targets>
    <target>lightning__AppPage</target>
    <target>lightning__RecordPage</target>
    <target>lightning__HomePage</target>
</targets>
```

### Chart Not Loading

The chart uses Chart.js loaded from a static resource. Verify:
1. The static resource `ChartJS` exists
2. It contains Chart.js v4.x

To add Chart.js if missing:
1. Download from https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.js
2. Upload as Static Resource named `ChartJS`

### Message Channel Errors

Deploy the message channel first:
```bash
sf project deploy start --source-dir force-app/main/default/messageChannels -o MyOrg
```

## Uninstallation

To remove the components:

```bash
# Create destructive manifest
sf project deploy start \
  --metadata LightningComponentBundle:commandCenterContainer \
  --metadata LightningComponentBundle:commandCenterChart \
  --metadata LightningComponentBundle:commandCenterFilterBar \
  --metadata LightningComponentBundle:commandCenterKpiRow \
  --metadata LightningComponentBundle:commandCenterStatusTable \
  --metadata LightningComponentBundle:commandCenterAccountTable \
  --metadata LightningComponentBundle:commandCenterHeader \
  --metadata LightningComponentBundle:commandCenterFooter \
  --metadata ApexClass:DashboardController \
  --metadata ApexClass:DashboardControllerTest \
  --metadata LightningMessageChannel:DashboardFilterChannel \
  --delete-metadata \
  -o MyOrg
```

## Support

For installation support, contact [support@revelateops.com](mailto:support@revelateops.com)
