import { LightningElement, api, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import FILTER_CHANNEL from '@salesforce/messageChannel/DashboardFilterChannel__c';

export default class CommandCenterFilterBar extends LightningElement {
    @api filterState = {};
    @api targetUniverseData = [];
    @api selectedPriorityCode = null;
    @api legendItems = [];

    prioritySeries = [
        { value: '500', label: 'D500', color: '#3b82f6' },  // Bright blue
        { value: '600', label: 'D600', color: '#a855f7' },  // Bright purple
        { value: '700', label: 'D700', color: '#ef4444' }   // Bright red
    ];

    @wire(MessageContext)
    messageContext;

    get prioritySeriesOptions() {
        const selectedSeries = this.filterState?.prioritySeries || [];
        const hasActiveFilter = selectedSeries.length > 0;
        return this.prioritySeries.map(series => ({
            ...series,
            isActive: hasActiveFilter && selectedSeries.includes(series.value),
            buttonClass: (hasActiveFilter && selectedSeries.includes(series.value))
                ? 'priority-btn selected'
                : 'priority-btn',
            colorStyle: `--series-color: ${series.color}`
        }));
    }

    get hasActiveSeriesFilter() {
        const selectedSeries = this.filterState?.prioritySeries || [];
        return selectedSeries.length > 0;
    }

    get allSeriesButtonClass() {
        // "All" is selected when no specific series filters are active
        return this.hasActiveSeriesFilter ? 'priority-btn' : 'priority-btn selected';
    }

    get statusFilters() {
        if (!this.targetUniverseData || this.targetUniverseData.length === 0) {
            return [];
        }

        const selectedStatuses = this.filterState?.targetStatuses || [];
        const hasActiveFilter = selectedStatuses.length > 0;

        return this.targetUniverseData.map(item => ({
            status: item.status,
            count: item.count,
            color: item.color,
            isSelected: hasActiveFilter && selectedStatuses.includes(item.status),
            chipClass: (hasActiveFilter && selectedStatuses.includes(item.status))
                ? 'status-chip selected'
                : 'status-chip',
            colorStyle: `--chip-color: ${item.color || '#706e6b'}`,
            labelWithCount: `${item.status} (${item.count})`
        }));
    }

    get hasActiveStatusFilter() {
        const selectedStatuses = this.filterState?.targetStatuses || [];
        return selectedStatuses.length > 0;
    }

    get allStatusChipClass() {
        // "All" is selected when no specific status filters are active
        return this.hasActiveStatusFilter ? 'status-chip' : 'status-chip selected';
    }

    get hasPriorityCodeFilter() {
        return this.selectedPriorityCode !== null;
    }

    get priorityCodeFilterLabel() {
        return `Priority: ${this.selectedPriorityCode}`;
    }

    get hasLegendItems() {
        return this.legendItems && this.legendItems.length > 0;
    }

    handlePriorityCodeClick(event) {
        const code = event.currentTarget.dataset.code;
        this.dispatchEvent(new CustomEvent('prioritycodeclick', {
            detail: { code }
        }));
    }

    handleSeriesClick(event) {
        const series = event.currentTarget.dataset.series;
        const currentSeries = this.filterState?.prioritySeries || [];

        let newSeries;
        if (currentSeries.includes(series)) {
            // Already selected - toggle off (remove from filter)
            newSeries = currentSeries.filter(s => s !== series);
        } else {
            // Not selected - toggle on (add to filter)
            newSeries = [...currentSeries, series];
        }

        publish(this.messageContext, FILTER_CHANNEL, {
            filterType: 'prioritySeries',
            filterValue: newSeries,
            source: 'filterBar'
        });
    }

    handleAllSeriesClick() {
        // Clear all series filters to show all series
        publish(this.messageContext, FILTER_CHANNEL, {
            filterType: 'prioritySeries',
            filterValue: [],
            source: 'filterBar'
        });
    }

    handleStatusClick(event) {
        const status = event.currentTarget.dataset.status;
        const currentStatuses = this.filterState?.targetStatuses || [];

        let newStatuses;
        if (currentStatuses.includes(status)) {
            // Already selected - toggle off (remove from filter)
            newStatuses = currentStatuses.filter(s => s !== status);
        } else {
            // Not selected - toggle on (add to filter)
            newStatuses = [...currentStatuses, status];
        }

        publish(this.messageContext, FILTER_CHANNEL, {
            filterType: 'targetStatuses',
            filterValue: newStatuses,
            source: 'filterBar'
        });
    }

    handleAllStatusClick() {
        // Clear all status filters to show all statuses
        publish(this.messageContext, FILTER_CHANNEL, {
            filterType: 'targetStatuses',
            filterValue: [],
            source: 'filterBar'
        });
    }

    handleClearStatusFilters() {
        publish(this.messageContext, FILTER_CHANNEL, {
            filterType: 'targetStatuses',
            filterValue: [],
            source: 'filterBar'
        });
    }

    handleClearPriorityCode() {
        this.dispatchEvent(new CustomEvent('clearpriority'));
    }

    handleResetFilters() {
        publish(this.messageContext, FILTER_CHANNEL, {
            filterType: 'reset',
            filterValue: null,
            source: 'filterBar'
        });
    }
}
