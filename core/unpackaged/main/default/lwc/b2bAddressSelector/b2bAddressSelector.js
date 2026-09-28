import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CartSummaryAdapter } from 'commerce/cartApi';
import getShippingAddresses from '@salesforce/apex/B2BAddressController.getShippingAddresses';
import saveSelectedAddressId from '@salesforce/apex/B2BAddressController.saveSelectedAddressId';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ToastContainer  from 'lightning/toastContainer';
import { SessionContextAdapter }  from 'commerce/contextApi';
import { createRecord, deleteRecord } from 'lightning/uiRecordApi';


export default class B2BAddressSelector extends NavigationMixin(LightningElement) {
    @api displayMode;
    @track addresses = [];
    @track error;
    effectiveAccountId;
    selectedAddressId;
    cartId;
    searchTerm = '';
    sortBy = 'LastUsedDate__c';
    visibleCount = 10;
    delayTimeout;
    wiredAddressesResult;
    showAddressModal = false;
    selectedDisplayMode;
    isEdit = false;
    isLoading = false;
    initialSelectionApplied = false;
    newAddress = {
        name:       '',
        street:     '',
        city:       '',
        state:      '',
        postalCode: '',
        country:    'US',
        ParentId: '',
        AddressType: '',
        isDefault: false
    };
    get effectiveSortDirection() {
        if (this.sortBy === 'Name' || this.sortBy === 'City') {
            return 'ASC';
        }
        return 'DESC';
    }
    get sortOptions() {
        return [
            { label: 'Recently Used', value: 'LastUsedDate__c' },
            { label: 'Name', value: 'Name' },
            { label: 'City', value: 'City' }
        ];
    }
    get computedAddresses() {
        return this.addresses.map(addr => ({
            ...addr,
            isSelected: addr.Id === this.selectedAddressId
        }));
    }
    get displayedAddresses() {
        return this.computedAddresses.slice(0, this.visibleCount);
    }
    get hasMoreAddresses() {
        return this.addresses.length > this.visibleCount;
    }
    connectedCallback() {
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts   = 5;
        toastContainer.toastPosition = 'top-center';

        if (this.displayMode === 'checkout') {
            this.selectedDisplayMode = false;
        }else{
            this.selectedDisplayMode = true;
        }
    }
    get queryParamsPayload() {
        return {
            accountId: this.effectiveAccountId,
            searchTerm: this.searchTerm,
            sortBy: this.sortBy,
            sortDirection: this.effectiveSortDirection
        };
    }
    @wire(SessionContextAdapter)
    wiredSession({ data, error }) {
        if (data) {
            this.effectiveAccountId = data.effectiveAccountId;
        } else if (error) {
            console.error('SessionContextAdapter error:', error);
        }
    }
    @wire(CartSummaryAdapter)
    wiredCartSummary({ data, error }) {
        if (data) {
            this.cartId = data.cartId;
        } else if (error) {
            console.error(error);
        }
    }
    @wire(getShippingAddresses, { request: '$queryParamsPayload' })
    wiredAddresses(result) {
        this.wiredAddressesResult = result;
        if (result.data) {
            //this.addresses = result.data;
            this.addresses = [...result.data].sort((a, b) => {
                const aPinned = a.IsDefault || a.Id === this.selectedAddressId;
                const bPinned = b.IsDefault || b.Id === this.selectedAddressId;
                if (aPinned === bPinned) {
                    return 0;
                }
                return aPinned ? -1 : 1;
            });
            this.visibleCount = 10;
            this.applyInitialSelection();
        }
    }
    applyInitialSelection() {
        if (this.displayMode !== 'checkout' || this.initialSelectionApplied) {
            return;
        }
        if (!this.addresses.length) {
            return;
        }
        this.initialSelectionApplied = true;

        const defaultAddress = this.addresses.find(addr => addr.IsDefault);
        if (!defaultAddress) {
            return;
        }
        this.selectAddress(defaultAddress.Id, { showToast: false });
    }
    async handleEdit(event){
        const addressId = event.currentTarget.dataset.id;
        this.selectedAddressId = addressId;
        this.isEdit = true;
        //await refreshApex(this.wiredAddressesResult);
    }

    async handleDelete(event){
        this.isEdit = false;
        const addressId = event.currentTarget.dataset.id;
        try {
            await deleteRecord(addressId);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Address deleted successfully.',
                    variant: 'success'
                })
            );

        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || 'Unable to delete address.',
                    variant: 'error'
                })
            );
        }
        await refreshApex(this.wiredAddressesResult);
    }

    handleNewAddress() {
        this.isLoading = true;
        this.newAddress = {
            name: '', street: '', city: '',
            state: '', postalCode: '', country: 'US', isDefault: false
        };
        this.showAddressModal = true;
        setTimeout(() => {
            this.isLoading = false;
        }, 1000);
    }
    handleCancel() {
        this.showAddressModal = false;
    }
    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.newAddress = {
            ...this.newAddress,
            [field]: event.target.type === 'checkbox' ? event.target.checked : event.target.value
        };
    }
    handleAddressChange(event) {
        this.newAddress = {
            ...this.newAddress,
            street: event.detail.street,
            city: event.detail.city,
            state: event.detail.province,
            postalCode: event.detail.postalCode,
            country: event.detail.country === 'United States' ? 'US' : event.detail.country
        };
    }
    async handleSaveAddress() {
        const addressInput = this.template.querySelector('lightning-input-address');
        const nameInput = this.template.querySelector('lightning-input[data-field="name"]');
        const nameValid = nameInput ? nameInput.reportValidity() : true;
        const addressValid = addressInput ? addressInput.reportValidity() : true;
        if (!nameValid || !addressValid) {
            return;
        }
        const missing = [];
        if (!this.newAddress.street) missing.push('Street');
        if (!this.newAddress.city) missing.push('City');
        if (!this.newAddress.country) missing.push('Country');
        if (!this.newAddress.state) missing.push('State / Province');
        if (!this.newAddress.postalCode) missing.push('ZIP / Postal Code');

        if (missing.length > 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Required fields missing',
                message: missing.join(', ') + ' must be filled in.',
                variant: 'error',
                mode: 'sticky'
            }));
            return;
        }

        if (!this.effectiveAccountId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Account context not available. Please refresh and try again.',
                variant: 'error'
            }));
            return;
        }
        const fields = {
            ParentId: this.effectiveAccountId,
            Name: this.newAddress.name,
            CompanyName: this.newAddress.name,
            Street: this.newAddress.street,
            City: this.newAddress.city,
            State: this.newAddress.state,
            PostalCode: this.newAddress.postalCode,
            Country: this.newAddress.country,
            AddressType: 'Shipping',
            IsDefault: this.newAddress.isDefault
        };
        const recordInput = {
            apiName: 'ContactPointAddress',
            fields
        };

        try {
            const result = await createRecord(recordInput);
            const newAddressId = result.id;
            this.selectAddress(newAddressId, { showToast: false });
            this.showAddressModal = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Address created successfully.',
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredAddressesResult);
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message:
                        error?.body?.message ||
                        'Unable to create address.',
                    variant: 'error'
                })
            );
        }
    }
    async handleAddressUpdated() {
        this.isEdit = false;
        await refreshApex(this.wiredAddressesResult);
    }
    handleAddressCancel(){
        this.isEdit = false;
    }
    async handleAddressDelete(){
        this.selectedAddressId = null;
        await refreshApex(this.wiredAddressesResult);
    }
    handleSearchChange(event) {
        window.clearTimeout(this.delayTimeout);
        const searchVal = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.searchTerm = searchVal;
        }, 300);
    }
    handleSortChange(event) {
        this.sortBy = event.detail.value;
    }
    handleLoadMore() {
        this.visibleCount += 10;
    }
    handleAddressSelect(event) {
        const addressId = event.currentTarget.dataset.id || event.target.dataset.id; //event.currentTarget.dataset.id;
        this.selectAddress(addressId);
    }
    selectAddress(addressId, { showToast = true } = {}) {
        this.selectedAddressId = addressId;

        if (this.displayMode === 'checkout') {
            this.selectedDisplayMode = false;
            const selectEvent = new CustomEvent('addressselect', {
                detail: { selectedAddressId: addressId }
            });
            this.dispatchEvent(selectEvent);
            if (this.cartId) {
                saveSelectedAddressId({
                    cartId: this.cartId,
                    addressId: addressId
                })
                    .then(() => {
                        if (showToast) {
                            this.dispatchEvent(new ShowToastEvent({
                                title: 'Success',
                                message: 'Address saved to cart.',
                                variant: 'success'
                            }));
                        }
                    })
                    .catch(error => {
                        console.error('CartDeliveryGroupService error:', error);
                    });
            }
        } else if (this.displayMode === 'management') {
            this.selectedDisplayMode = true;
        }
    }
}