import { LightningElement, api } from 'lwc';

export default class CommandCenterKpiRow extends LightningElement {
    @api kpiData = null;
    @api isLoading = false;
    @api displayMode = 'count'; // 'count' or 'revenue'

    get totalAccounts() {
        if (!this.kpiData) return '—';
        return this.formatNumber(this.kpiData.totalAccounts || 0);
    }

    get totalAssets() {
        if (!this.kpiData) return '—';
        const assets = this.kpiData.totalAssets || 0;
        return this.formatCurrency(assets);
    }

    get countCardClass() {
        return this.displayMode === 'count'
            ? 'kpi-card selectable selected'
            : 'kpi-card selectable';
    }

    get revenueCardClass() {
        return this.displayMode === 'revenue'
            ? 'kpi-card selectable selected'
            : 'kpi-card selectable';
    }

    handleCountClick() {
        if (this.displayMode !== 'count') {
            this.dispatchEvent(new CustomEvent('displaymodechange', {
                detail: { mode: 'count' },
                bubbles: true,
                composed: true
            }));
        }
    }

    handleRevenueClick() {
        if (this.displayMode !== 'revenue') {
            this.dispatchEvent(new CustomEvent('displaymodechange', {
                detail: { mode: 'revenue' },
                bubbles: true,
                composed: true
            }));
        }
    }

    formatNumber(num) {
        if (num === null || num === undefined) return '—';
        return new Intl.NumberFormat('en-US').format(num);
    }

    formatCurrency(num) {
        if (num === null || num === undefined) return '—';
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(num);
    }
}
