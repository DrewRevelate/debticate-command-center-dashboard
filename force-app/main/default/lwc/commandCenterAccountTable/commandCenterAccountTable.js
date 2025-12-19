import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateAccountField from '@salesforce/apex/DashboardController.updateAccountField';

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

const STATUS_OPTIONS = [
    { label: 'Target A', value: 'Target A' },
    { label: 'Target B', value: 'Target B' },
    { label: 'Target C', value: 'Target C' },
    { label: 'Target D', value: 'Target D' },
    { label: 'Customer', value: 'Customer' },
    { label: 'Opportunity', value: 'Opportunity' },
    { label: 'Dead', value: 'Dead' },
    { label: 'Partner', value: 'Partner' }
];

const PRIORITY_OPTIONS = Object.entries(PRIORITY_LABELS).map(([value, label]) => ({
    label: `${value} - ${label}`,
    value: value
}));

export default class CommandCenterAccountTable extends NavigationMixin(LightningElement) {
    @api accounts = [];
    @api selectedPriorityCodes = []; // Multi-select priority codes

    // Sorting state
    @track sortField = 'name';
    @track sortDirection = 'asc';

    // Edit mode state
    @track isEditMode = false;

    statusOptions = STATUS_OPTIONS;
    priorityOptions = PRIORITY_OPTIONS;

    get tableData() {
        if (!this.accounts || this.accounts.length === 0) {
            return [];
        }

        // Map accounts to display format
        const selectedCodes = this.selectedPriorityCodes || [];
        let data = this.accounts.map(acc => {
            const isHighlighted = selectedCodes.length > 0 && selectedCodes.includes(acc.priority);

            return {
                id: acc.id,
                name: acc.name,
                annualRevenue: acc.annualRevenue || 0,
                formattedRevenue: this.formatCurrency(acc.annualRevenue),
                status: acc.status,
                priority: acc.priority,
                priorityDescription: this.getPriorityDescription(acc.priority),
                url: acc.url,
                statusClass: this.getStatusClass(acc.status),
                rowClass: isHighlighted ? 'highlighted' : ''
            };
        });

        // Apply sorting
        data = this.sortData(data);

        return data;
    }

    sortData(data) {
        const field = this.sortField;
        const direction = this.sortDirection === 'asc' ? 1 : -1;

        return [...data].sort((a, b) => {
            let valueA = a[field];
            let valueB = b[field];

            // Handle null/undefined
            if (valueA == null) valueA = '';
            if (valueB == null) valueB = '';

            // Numeric comparison for revenue
            if (field === 'annualRevenue') {
                return (valueA - valueB) * direction;
            }

            // String comparison
            if (typeof valueA === 'string') {
                valueA = valueA.toLowerCase();
                valueB = valueB.toLowerCase();
            }

            if (valueA < valueB) return -1 * direction;
            if (valueA > valueB) return 1 * direction;
            return 0;
        });
    }

    get hasData() {
        return this.tableData.length > 0;
    }

    get recordCount() {
        return this.tableData.length;
    }

    // Sort indicator classes
    get nameSortClass() {
        return this.getSortClass('name');
    }

    get revenueSortClass() {
        return this.getSortClass('annualRevenue');
    }

    get statusSortClass() {
        return this.getSortClass('status');
    }

    get prioritySortClass() {
        return this.getSortClass('priority');
    }

    getSortClass(field) {
        if (this.sortField !== field) {
            return 'sortable';
        }
        return this.sortDirection === 'asc' ? 'sortable sorted-asc' : 'sortable sorted-desc';
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;

        if (this.sortField === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDirection = 'asc';
        }
    }

    handleToggleEditMode() {
        this.isEditMode = !this.isEditMode;
    }

    getPriorityDescription(priority) {
        if (!priority) return '';
        return PRIORITY_LABELS[priority] || priority;
    }

    getStatusClass(status) {
        if (!status) return 'status-badge';
        const statusMap = {
            'Customer': 'status-badge status-customer',
            'Dead': 'status-badge status-dead',
            'Opportunity': 'status-badge status-opportunity',
            'Target A': 'status-badge status-target-a',
            'Target B': 'status-badge status-target-b',
            'Target C': 'status-badge status-target-c',
            'Target D': 'status-badge status-target-d',
            'Partner': 'status-badge status-partner'
        };
        return statusMap[status] || 'status-badge';
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

    handleAccountClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const accountId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: accountId,
                objectApiName: 'Account',
                actionName: 'view'
            }
        });
    }

    async handleFieldChange(event) {
        const rowId = event.target.dataset.rowId;
        const field = event.target.dataset.field;
        const newValue = event.target.value;

        try {
            const fieldMap = {
                'status': 'Target_Status__c',
                'priority': 'Priority_Code__c'
            };

            const apexField = fieldMap[field];
            if (!apexField) {
                console.error('Unknown field:', field);
                return;
            }

            await updateAccountField({
                accountId: rowId,
                fieldName: apexField,
                fieldValue: newValue
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: `${field === 'status' ? 'Status' : 'Priority'} updated`,
                variant: 'success'
            }));

            // Notify parent to refresh data
            this.dispatchEvent(new CustomEvent('recordupdate', {
                detail: { accountId: rowId, field, newValue }
            }));

        } catch (error) {
            console.error('Error updating field:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to update record',
                variant: 'error'
            }));
        }
    }
}
