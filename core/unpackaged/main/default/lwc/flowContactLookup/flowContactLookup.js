import { LightningElement, api, track, wire } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import { refreshApex } from '@salesforce/apex';
import searchRelatedContacts from '@salesforce/apex/FlowContactLookupController.searchRelatedContacts';
import getContactById from '@salesforce/apex/FlowContactLookupController.getContactById';

const SEARCH_DEBOUNCE_MS = 300;
const MIN_SEARCH_LENGTH = 0;

export default class FlowContactLookup extends LightningElement {
    @api accountId;
    @api label = 'Contact';
    @api placeholder = 'Search contacts...';

    @api selectedContactId;
    @api selectedContactName;

    @track searchTerm = '';
    @track results = [];
    @track isOpen = false;
    @track loading = false;
    @track errorMessage = '';

    _debounceTimer;
    _wiredResults;
    _activeAccountId;

    connectedCallback() {
        this._activeAccountId = this.accountId;
        if (this.selectedContactId && !this.selectedContactName) {
            this.hydrateExistingSelection();
        }
    }

    renderedCallback() {
        if (this.accountId !== this._activeAccountId) {
            this._activeAccountId = this.accountId;
            this.clearSelection(false);
            this.searchTerm = '';
            this.results = [];
        }
    }

    @wire(searchRelatedContacts, { accountId: '$accountId', searchTerm: '$searchTerm' })
    wiredContacts(value) {
        this._wiredResults = value;
        const { data, error } = value;
        this.loading = false;
        if (data) {
            this.results = data.map((row) => ({
                id: row.id,
                name: row.name,
                subtitle: this.buildSubtitle(row)
            }));
            this.errorMessage = '';
        } else if (error) {
            this.results = [];
            this.errorMessage = this.reduceError(error);
        }
    }

    buildSubtitle(row) {
        const parts = [];
        if (row.title) parts.push(row.title);
        if (row.email) parts.push(row.email);
        return parts.join(' • ');
    }

    reduceError(error) {
        if (!error) return '';
        if (Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
        if (error.body && error.body.message) return error.body.message;
        if (typeof error.message === 'string') return error.message;
        return 'Unknown error';
    }

    async hydrateExistingSelection() {
        try {
            const contact = await getContactById({ contactId: this.selectedContactId });
            if (contact) {
                this.selectedContactName = contact.name;
                this.dispatchFlowChange('selectedContactName', contact.name);
            }
        } catch (e) {
            // Non-fatal — user can re-select.
        }
    }

    handleInput(event) {
        const value = event.target.value;
        if (this._debounceTimer) {
            clearTimeout(this._debounceTimer);
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._debounceTimer = setTimeout(() => {
            if (value.length >= MIN_SEARCH_LENGTH) {
                this.loading = true;
                this.searchTerm = value;
            }
        }, SEARCH_DEBOUNCE_MS);
    }

    handleFocus() {
        if (!this.accountId) return;
        this.isOpen = true;
    }

    handleBlur() {
        // Delay so click on a result registers before the dropdown closes.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.isOpen = false;
        }, 200);
    }

    handleSelect(event) {
        const id = event.currentTarget.dataset.id;
        const picked = this.results.find((r) => r.id === id);
        if (!picked) return;

        this.selectedContactId = picked.id;
        this.selectedContactName = picked.name;
        this.dispatchFlowChange('selectedContactId', picked.id);
        this.dispatchFlowChange('selectedContactName', picked.name);
        this.isOpen = false;
        this.searchTerm = '';
    }

    handleClear() {
        this.clearSelection(true);
    }

    clearSelection(notifyFlow) {
        this.selectedContactId = null;
        this.selectedContactName = null;
        this.searchTerm = '';
        if (notifyFlow) {
            this.dispatchFlowChange('selectedContactId', null);
            this.dispatchFlowChange('selectedContactName', null);
        }
        if (this._wiredResults) {
            refreshApex(this._wiredResults);
        }
    }

    dispatchFlowChange(attributeName, value) {
        this.dispatchEvent(new FlowAttributeChangeEvent(attributeName, value));
    }

    get hasSelection() {
        return !!this.selectedContactId;
    }

    get showDropdown() {
        return this.isOpen && !this.hasSelection && !!this.accountId;
    }

    get hasResults() {
        return this.results && this.results.length > 0;
    }

    get showNoResults() {
        return this.showDropdown && !this.loading && !this.hasResults;
    }

    get disabledInput() {
        return !this.accountId;
    }

    get computedPlaceholder() {
        return this.accountId ? this.placeholder : 'Select an account first';
    }

    get comboboxClass() {
        let css = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
        if (this.showDropdown) css += ' slds-is-open';
        return css;
    }

    get formElementClass() {
        return 'slds-form-element';
    }
}