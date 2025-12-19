import { LightningElement, wire, track, api } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import FILTER_CHANNEL from '@salesforce/messageChannel/DashboardFilterChannel__c';
import getDashboardData from '@salesforce/apex/DashboardController.getDashboardData';

const PRIORITY_LABELS = {
    '500': 'Needs Engagement',
    '501': 'Customers',
    '502': 'Existing Opportunity/Handoff Accounts',
    '503': 'Dormant',
    '510': 'In qualification cadence',
    '511': 'Stalled in cadence',
    '512': 'Meeting Set',
    '513': 'Opportunity',
    '553': 'No Response Pool',
    '554': 'Dead for now...',
    '555': 'Never - Do Not Contact',
    '600': 'Non-Bank Target',
    '601': 'Non-Bank Customer',
    '700': 'International Bank',
    '701': 'International Customer'
};

export default class CommandCenterContainer extends LightningElement {
    @api title = 'Command Center';

    @track filterState = {
        targetStatuses: [],
        prioritySeries: [],  // Empty = show all series (no filter)
        engagementStatus: null,
        searchTerm: '',
        top525: false
    };

    @track dashboardData = null;
    @track isLoading = true;
    @track error = null;
    @track chartType = 'vertical';
    @track selectedPriorityCode = null;
    @track chartDisplayMode = 'count'; // 'count' or 'revenue'

    // Cache the full status list for filter bar (doesn't change with filters)
    @track allStatusOptions = [];

    subscription = null;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.subscribeToChannel();
        this.loadDashboardData();
    }

    disconnectedCallback() {
        this.unsubscribeFromChannel();
    }

    subscribeToChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                FILTER_CHANNEL,
                (message) => this.handleFilterMessage(message)
            );
        }
    }

    unsubscribeFromChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    handleFilterMessage(message) {
        const { filterType, filterValue } = message;

        switch (filterType) {
            case 'prioritySeries':
                this.filterState = { ...this.filterState, prioritySeries: filterValue };
                // Clear priority code selection if it's no longer in a visible series
                if (this.selectedPriorityCode && filterValue.length > 0) {
                    const codePrefix = this.selectedPriorityCode.charAt(0);
                    const seriesMap = { '5': '500', '6': '600', '7': '700' };
                    if (!filterValue.includes(seriesMap[codePrefix])) {
                        this.selectedPriorityCode = null;
                    }
                }
                break;
            case 'targetStatuses':
                this.filterState = { ...this.filterState, targetStatuses: filterValue };
                break;
            case 'engagementStatus':
                this.filterState = { ...this.filterState, engagementStatus: filterValue };
                break;
            case 'chartType':
                this.chartType = filterValue;
                return;
            case 'priorityCode':
                this.selectedPriorityCode = filterValue;
                return;
            case 'reset':
                this.filterState = {
                    targetStatuses: [],
                    prioritySeries: [],  // Empty = show all series (no filter)
                    engagementStatus: null,
                    searchTerm: '',
                    top525: false
                };
                this.selectedPriorityCode = null;
                break;
            default:
                return;
        }

        this.loadDashboardData();
    }

    async loadDashboardData() {
        this.isLoading = true;
        this.error = null;

        try {
            const result = await getDashboardData({ filters: this.filterState });
            this.dashboardData = result;

            // Cache the full status list when no status filters are applied
            // This ensures the filter bar always shows all status options
            const hasNoStatusFilter = !this.filterState.targetStatuses || this.filterState.targetStatuses.length === 0;
            if (hasNoStatusFilter && result?.targetUniverse?.length > 0) {
                this.allStatusOptions = result.targetUniverse;
            }
        } catch (err) {
            console.error('Error loading dashboard data:', err);
            this.error = err.body?.message || 'Failed to load dashboard data';
        } finally {
            this.isLoading = false;
        }
    }

    handleChartTypeChange(event) {
        this.chartType = event.detail.chartType;
    }

    handleDisplayModeChange(event) {
        this.chartDisplayMode = event.detail.mode;
    }

    handleBarClick(event) {
        this.selectedPriorityCode = event.detail.priorityCode;
    }

    handleClearPriorityFilter() {
        this.selectedPriorityCode = null;
    }

    handlePriorityCodeClickEvent(event) {
        const code = event.detail.code;
        // Toggle: if clicking the same code, clear the filter
        this.selectedPriorityCode = code === this.selectedPriorityCode ? null : code;
    }

    handleRecordUpdate() {
        // Refresh data after an inline edit
        this.loadDashboardData();
    }

    get hasData() {
        return this.dashboardData !== null;
    }

    get targetUniverseData() {
        // Return cached full status list for filter bar (always shows all options)
        // Fall back to current data if cache not yet populated
        return this.allStatusOptions.length > 0
            ? this.allStatusOptions
            : (this.dashboardData?.targetUniverse || []);
    }

    get cadenceMatrixData() {
        return this.dashboardData?.cadenceMatrix || null;
    }

    get kpiSummary() {
        return this.dashboardData?.kpiSummary || null;
    }

    get filteredAccounts() {
        const accounts = this.dashboardData?.filteredAccounts || [];
        if (this.selectedPriorityCode) {
            return accounts.filter(acc => acc.priority === this.selectedPriorityCode);
        }
        return accounts;
    }

    get chartData() {
        if (!this.cadenceMatrixData) return [];

        const priorityMap = new Map();
        const selectedSeries = this.filterState.prioritySeries || [];
        // Empty array means "All" - show all series
        const showAllSeries = selectedSeries.length === 0;

        const processSeriesData = (seriesData, seriesPrefix) => {
            if (!seriesData) return;
            seriesData.forEach(item => {
                const existing = priorityMap.get(item.priority) || { count: 0, assets: 0 };
                priorityMap.set(item.priority, {
                    count: existing.count + item.count,
                    assets: existing.assets + (item.totalAssets || 0),
                    priority: item.priority,
                    series: seriesPrefix
                });
            });
        };

        if (showAllSeries || selectedSeries.includes('500')) {
            processSeriesData(this.cadenceMatrixData.series500, '500');
        }
        if (showAllSeries || selectedSeries.includes('600')) {
            processSeriesData(this.cadenceMatrixData.series600, '600');
        }
        if (showAllSeries || selectedSeries.includes('700')) {
            processSeriesData(this.cadenceMatrixData.series700, '700');
        }

        const result = [];
        priorityMap.forEach((data, priority) => {
            result.push({
                label: priority,
                value: data.count,
                assets: data.assets,
                color: this.getPriorityColor(priority),
                series: data.series
            });
        });

        return result.sort((a, b) => a.label.localeCompare(b.label));
    }

    getPriorityColor(priority) {
        if (!priority) return '#bdc3c7';

        // Gradient shades within each series - darker for lower codes, lighter for higher
        // D500 series - Blue gradient
        const blue500 = {
            '500': '#1e40af',  // Dark blue
            '501': '#1d4ed8',
            '502': '#2563eb',
            '503': '#3b82f6',  // Base blue
            '510': '#60a5fa',
            '511': '#93c5fd',
            '512': '#7dd3fc',
            '513': '#38bdf8',
            '550': '#22d3ee',  // Cyan range
            '553': '#67e8f9',
            '554': '#a5f3fc',
            '555': '#cffafe'   // Lightest
        };

        // D600 series - Purple gradient
        const purple600 = {
            '600': '#7c3aed',  // Dark purple
            '601': '#a78bfa',  // Light purple
            '602': '#c4b5fd',
            '603': '#ddd6fe'
        };

        // D700 series - Red/Orange gradient
        const red700 = {
            '700': '#991b1b',  // Darkest red
            '701': '#b91c1c',
            '702': '#dc2626',
            '703': '#ef4444',  // Base red
            '710': '#f87171',
            '711': '#fca5a5',
            '750': '#f97316',  // Orange range
            '751': '#fb923c',
            '752': '#fdba74',
            '753': '#fed7aa'
        };

        // Check specific codes first
        if (blue500[priority]) return blue500[priority];
        if (purple600[priority]) return purple600[priority];
        if (red700[priority]) return red700[priority];

        // Fallback gradient based on last two digits within series
        if (priority.startsWith('5')) {
            const suffix = parseInt(priority.substring(1), 10);
            if (suffix < 10) return '#2563eb';       // 500-509: Medium blue
            if (suffix < 50) return '#60a5fa';       // 510-549: Light blue
            return '#67e8f9';                         // 550-599: Cyan
        }
        if (priority.startsWith('6')) return '#a855f7';  // D600 fallback
        if (priority.startsWith('7')) return '#ef4444';  // D700 fallback

        return '#6b7280';  // Fallback gray
    }

    get statusSummaryData() {
        if (!this.targetUniverseData || this.targetUniverseData.length === 0) return [];

        return this.targetUniverseData.map(item => ({
            status: item.status,
            count: item.count,
            color: item.color,
            revenue: this.calculateRevenueForStatus(item.status)
        }));
    }

    get legendItems() {
        const chartData = this.chartData;
        if (!chartData || chartData.length === 0) return [];

        // Check which series are selected (empty = All)
        const selectedSeries = this.filterState.prioritySeries || [];
        const showAllSeries = selectedSeries.length === 0;

        // Group by series (500s, 600s, 700s)
        const series500 = [];
        const series600 = [];
        const series700 = [];

        chartData.forEach(item => {
            const isSelected = this.selectedPriorityCode === item.label;
            const legendItem = {
                code: item.label,
                color: item.color,
                colorStyle: `--chip-color: ${item.color}`,
                description: PRIORITY_LABELS[item.label] || `Priority ${item.label}`,
                buttonClass: isSelected ? 'priority-code-chip selected' : 'priority-code-chip'
            };

            if (item.label.startsWith('5')) {
                series500.push(legendItem);
            } else if (item.label.startsWith('6')) {
                series600.push(legendItem);
            } else if (item.label.startsWith('7')) {
                series700.push(legendItem);
            }
        });

        const groups = [];
        // Only show series that are selected (or all if none selected)
        if ((showAllSeries || selectedSeries.includes('500')) && series500.length > 0) {
            groups.push({ series: '500', label: 'D500', color: '#3b82f6', items: series500 });
        }
        if ((showAllSeries || selectedSeries.includes('600')) && series600.length > 0) {
            groups.push({ series: '600', label: 'D600', color: '#a855f7', items: series600 });
        }
        if ((showAllSeries || selectedSeries.includes('700')) && series700.length > 0) {
            groups.push({ series: '700', label: 'D700', color: '#ef4444', items: series700 });
        }

        return groups;
    }

    get hasLegendItems() {
        return this.legendItems && this.legendItems.length > 0;
    }

    calculateRevenueForStatus(status) {
        if (!this.dashboardData?.filteredAccounts) return 0;

        return this.dashboardData.filteredAccounts
            .filter(acc => acc.status === status)
            .reduce((sum, acc) => sum + (acc.annualRevenue || 0), 0);
    }
}
