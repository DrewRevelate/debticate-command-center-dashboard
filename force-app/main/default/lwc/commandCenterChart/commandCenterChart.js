import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import ChartJs from '@salesforce/resourceUrl/ChartJs';

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

export default class CommandCenterChart extends LightningElement {
    @api chartType = 'vertical';

    @track _selectedPriorityCodes = []; // Multi-select priority codes
    @track _displayMode = 'count'; // 'count' or 'revenue'

    @api
    get selectedPriorityCodes() {
        return this._selectedPriorityCodes;
    }
    set selectedPriorityCodes(value) {
        this._selectedPriorityCodes = value || [];
        if (this.chartJsLoaded && this._chartData.length > 0) {
            this.updateChart();
        }
    }
    @track _chartData = [];
    @track chartJsLoaded = false;
    @track chartError = null;

    @api
    get displayMode() {
        return this._displayMode;
    }
    set displayMode(value) {
        this._displayMode = value || 'count';
        if (this.chartJsLoaded && this._chartData.length > 0) {
            this.updateChart();
        }
    }

    chart = null;

    @api
    get chartData() {
        return this._chartData;
    }
    set chartData(value) {
        this._chartData = value || [];
        if (this.chartJsLoaded && this._chartData.length > 0) {
            this.updateChart();
        }
    }

    get hasData() {
        return this._chartData && this._chartData.length > 0;
    }

    get dataLabel() {
        return this._displayMode === 'revenue' ? 'Revenue' : 'Record Count';
    }

    // Get the appropriate value based on display mode
    getDisplayValue(item) {
        if (this._displayMode === 'revenue') {
            return item.assets || 0;
        }
        return item.value || 0;
    }

    get isVerticalBar() {
        return this.chartType === 'vertical';
    }

    get isHorizontalBar() {
        return this.chartType === 'horizontal';
    }

    get verticalIconClass() {
        return this.chartType === 'vertical' ? 'chart-type-icon active' : 'chart-type-icon';
    }

    get horizontalIconClass() {
        return this.chartType === 'horizontal' ? 'chart-type-icon active' : 'chart-type-icon';
    }

    get legendItems() {
        if (!this._chartData || this._chartData.length === 0) return [];

        return this._chartData.map(item => ({
            code: item.label,
            color: item.color,
            colorStyle: `background: ${item.color}`,
            description: PRIORITY_LABELS[item.label] || `Priority ${item.label}`
        }));
    }

    renderedCallback() {
        if (this.chartJsLoaded) {
            return;
        }

        loadScript(this, ChartJs)
            .then(() => {
                this.chartJsLoaded = true;
                this.initializeChart();
            })
            .catch(error => {
                this.chartError = 'Failed to load Chart.js: ' + error.message;
                console.error('Chart.js load error:', error);
            });
    }

    initializeChart() {
        if (!this.hasData) return;

        // Small delay to ensure canvas is rendered
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.createChart();
        }, 50);
    }

    createChart() {
        const canvas = this.template.querySelector('canvas.chart-canvas');
        if (!canvas) {
            console.warn('Canvas element not found');
            return;
        }

        // Destroy existing chart if any
        if (this.chart) {
            this.chart.destroy();
            this.chart = null;
        }

        const ctx = canvas.getContext('2d');
        const config = this.getChartConfig();

        this.chart = new window.Chart(ctx, config);
    }

    updateChart() {
        if (!this.chart) {
            this.createChart();
            return;
        }

        // Update data and labels - use getDisplayValue for count/revenue toggle
        const labels = this._chartData.map(d => d.label);
        const data = this._chartData.map(d => this.getDisplayValue(d));
        const colors = this._chartData.map(d => d.color);

        this.chart.data.labels = labels;
        this.chart.data.datasets[0].data = data;
        this.chart.data.datasets[0].label = this.dataLabel;

        // Apply opacity to non-selected bars when bars are selected
        if (this._selectedPriorityCodes.length > 0) {
            this.chart.data.datasets[0].backgroundColor = this._chartData.map(d =>
                this._selectedPriorityCodes.includes(d.label) ? d.color : this.adjustColorOpacity(d.color, 0.3)
            );
        } else {
            this.chart.data.datasets[0].backgroundColor = colors;
        }

        this.chart.update('none'); // No animation on update for performance
    }

    getChartConfig() {
        const labels = this._chartData.map(d => d.label);
        const data = this._chartData.map(d => this.getDisplayValue(d));
        const colors = this._chartData.map(d => d.color);

        const baseConfig = {
            data: {
                labels: labels,
                datasets: [{
                    label: this.dataLabel,
                    data: data,
                    backgroundColor: colors,
                    borderWidth: 0,
                    borderRadius: 6,
                    borderSkipped: false
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                interaction: {
                    intersect: false,
                    mode: 'index'
                },
                onClick: (event, elements) => this.handleChartClick(event, elements),
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        backgroundColor: 'rgba(27, 42, 71, 0.95)',
                        titleFont: {
                            family: "'Salesforce Sans', Arial, sans-serif",
                            size: 13,
                            weight: '600'
                        },
                        bodyFont: {
                            family: "'Salesforce Sans', Arial, sans-serif",
                            size: 12
                        },
                        padding: 12,
                        cornerRadius: 8,
                        displayColors: true,
                        boxPadding: 6,
                        callbacks: {
                            title: (tooltipItems) => {
                                const priorityCode = tooltipItems[0]?.label || '';
                                const description = PRIORITY_LABELS[priorityCode] || '';
                                return description ? `${priorityCode}: ${description}` : priorityCode;
                            },
                            label: (context) => {
                                const value = context.parsed.y ?? context.parsed;
                                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                const percentage = ((value / total) * 100).toFixed(1);
                                if (this._displayMode === 'revenue') {
                                    const formatted = new Intl.NumberFormat('en-US', {
                                        style: 'currency',
                                        currency: 'USD',
                                        minimumFractionDigits: 0,
                                        maximumFractionDigits: 0
                                    }).format(value);
                                    return ` ${formatted} (${percentage}%)`;
                                }
                                return ` ${value.toLocaleString()} accounts (${percentage}%)`;
                            }
                        }
                    }
                },
                animation: {
                    duration: 750,
                    easing: 'easeOutQuart'
                }
            }
        };

        if (this.isHorizontalBar) {
            return this.getHorizontalBarConfig(baseConfig);
        } else {
            return this.getVerticalBarConfig(baseConfig);
        }
    }

    getVerticalBarConfig(baseConfig) {
        return {
            type: 'bar',
            data: baseConfig.data,
            options: {
                ...baseConfig.options,
                indexAxis: 'x',
                scales: {
                    x: {
                        grid: {
                            display: false
                        },
                        ticks: {
                            font: {
                                family: "'Salesforce Sans', Arial, sans-serif",
                                size: 11
                            },
                            color: '#706e6b'
                        }
                    },
                    y: {
                        beginAtZero: true,
                        grid: {
                            color: 'rgba(230, 236, 242, 0.8)',
                            drawBorder: false
                        },
                        ticks: {
                            font: {
                                family: "'Salesforce Sans', Arial, sans-serif",
                                size: 11
                            },
                            color: '#706e6b',
                            padding: 8
                        }
                    }
                },
                plugins: {
                    ...baseConfig.options.plugins,
                    datalabels: {
                        display: true,
                        anchor: 'end',
                        align: 'top',
                        color: '#16325c',
                        font: {
                            weight: '600',
                            size: 11
                        }
                    }
                }
            }
        };
    }

    getHorizontalBarConfig(baseConfig) {
        return {
            type: 'bar',
            data: baseConfig.data,
            options: {
                ...baseConfig.options,
                indexAxis: 'y',
                scales: {
                    x: {
                        beginAtZero: true,
                        grid: {
                            color: 'rgba(230, 236, 242, 0.8)',
                            drawBorder: false
                        },
                        ticks: {
                            font: {
                                family: "'Salesforce Sans', Arial, sans-serif",
                                size: 11
                            },
                            color: '#706e6b'
                        }
                    },
                    y: {
                        grid: {
                            display: false
                        },
                        ticks: {
                            font: {
                                family: "'Salesforce Sans', Arial, sans-serif",
                                size: 11
                            },
                            color: '#706e6b',
                            padding: 8
                        }
                    }
                }
            }
        };
    }

    handleChartClick(event, elements) {
        if (elements && elements.length > 0) {
            const index = elements[0].index;
            const priorityCode = this._chartData[index]?.label;
            if (priorityCode) {
                // Send the clicked code - parent handles toggle logic for multi-select
                this.dispatchEvent(new CustomEvent('barclick', {
                    detail: { priorityCode }
                }));
            }
        }
    }

    handleChartTypeClick(event) {
        const selectedType = event.currentTarget.dataset.type;
        if (selectedType !== this.chartType) {
            this.dispatchEvent(new CustomEvent('charttypechange', {
                detail: { chartType: selectedType }
            }));

            // Recreate chart with new type after a brief delay
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.createChart();
            }, 100);
        }
    }

    // Color utility functions
    adjustColorBrightness(hex, percent) {
        const num = parseInt(hex.replace('#', ''), 16);
        const amt = Math.round(2.55 * percent);
        const R = (num >> 16) + amt;
        const G = (num >> 8 & 0x00FF) + amt;
        const B = (num & 0x0000FF) + amt;
        return '#' + (
            0x1000000 +
            (R < 255 ? (R < 1 ? 0 : R) : 255) * 0x10000 +
            (G < 255 ? (G < 1 ? 0 : G) : 255) * 0x100 +
            (B < 255 ? (B < 1 ? 0 : B) : 255)
        ).toString(16).slice(1);
    }

    adjustColorOpacity(hex, opacity) {
        const num = parseInt(hex.replace('#', ''), 16);
        const R = num >> 16;
        const G = num >> 8 & 0x00FF;
        const B = num & 0x0000FF;
        return `rgba(${R}, ${G}, ${B}, ${opacity})`;
    }

    disconnectedCallback() {
        if (this.chart) {
            this.chart.destroy();
            this.chart = null;
        }
    }
}
