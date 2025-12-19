import { LightningElement, api } from 'lwc';

export default class CommandCenterStatusTable extends LightningElement {
    @api statusData = [];

    get tableData() {
        if (!this.statusData || this.statusData.length === 0) {
            return [];
        }

        return this.statusData.map(item => ({
            ...item,
            formattedRevenue: this.formatCurrency(item.revenue),
            statusStyle: `border-left: 4px solid ${item.color};`
        }));
    }

    get hasData() {
        return this.tableData.length > 0;
    }

    get totalRevenue() {
        if (!this.statusData) return '$0';
        const total = this.statusData.reduce((sum, item) => sum + (item.revenue || 0), 0);
        return this.formatCurrency(total);
    }

    formatCurrency(num) {
        if (num === null || num === undefined || num === 0) return '$0';
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(num);
    }
}
