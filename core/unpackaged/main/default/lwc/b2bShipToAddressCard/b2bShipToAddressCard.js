import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import NAME_FIELD from '@salesforce/schema/ContactPointAddress.Name';
import STREET_FIELD from '@salesforce/schema/ContactPointAddress.Street';
import CITY_FIELD from '@salesforce/schema/ContactPointAddress.City';
import STATE_FIELD from '@salesforce/schema/ContactPointAddress.State';
import ZIP_FIELD from '@salesforce/schema/ContactPointAddress.PostalCode';
import ISDEFAULT_FIELD from '@salesforce/schema/ContactPointAddress.IsDefault';

const ADDRESS_FIELDS = [NAME_FIELD, STREET_FIELD, CITY_FIELD, STATE_FIELD, ZIP_FIELD, ISDEFAULT_FIELD];

export default class B2bShipToAddressCard extends LightningElement {
    @api recordId;

    isLoading = true;
    isEditing = false;
    error;
    addressData;

    @wire(getRecord, { recordId: '$recordId', fields: ADDRESS_FIELDS })
    wiredAddressRecord({ error, data }) {
        if (data) {
            this.addressData = data;
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error;
            this.addressData = undefined;
            this.isLoading = false;
        }
    }

    get addressName() {
        return getFieldValue(this.addressData, NAME_FIELD);
    }

    get street() {
        return getFieldValue(this.addressData, STREET_FIELD);
    }

    get cityStateZip() {
        const city = getFieldValue(this.addressData, CITY_FIELD) || '';
        const state = getFieldValue(this.addressData, STATE_FIELD) || '';
        const zip = getFieldValue(this.addressData, ZIP_FIELD) || '';
        return (city || state || zip) ? `${city}, ${state} ${zip}`.trim() : '';
    }

    handleCancel() {
        this.dispatchEvent(
            new CustomEvent('addresscancel', {
                bubbles: true,
                composed: true
            }));
    }

    handleSaveSuccess() {
        this.isEditing = false;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Address updated successfully.',
            variant: 'success'
        }));
        this.dispatchEvent(
            new CustomEvent('addressupdated', {
                bubbles: true,
                composed: true
            }));
    }

    handleSaveError(event) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: event.detail.detail,
            variant: 'error'
        }));
    }

}