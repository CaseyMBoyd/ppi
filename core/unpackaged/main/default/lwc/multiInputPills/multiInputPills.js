import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';

export default class MultiInputPills extends LightningElement {
    @api cardTitle;
    @api inputLabel;
    @api fieldApiName;
    @api recordId;
    @api objectApiName;

    inputValue = '';
    values = [];
    isSaving = false;
    pendingSync = false;
    initializedRecordContext = '';
    lastSavedContext = '';
    lastSavedValue = '';

    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    objectInfo;

    @wire(getRecord, { recordId: '$recordId', fields: '$recordFields' })
    wiredRecord({ data, error }) {
        const contextKey = this.recordContextKey;
        if (!contextKey || this.initializedRecordContext === contextKey) {
            return;
        }

        if (error) {
            this.initializedRecordContext = contextKey;

            if (this.pendingSync) {
                this.pendingSync = false;
                this.requestRecordSync();
            }
            return;
        }

        if (!data) {
            return;
        }

        const currentFieldName = this.resolvedFieldApiName;
        const rawValue = data.fields?.[currentFieldName]?.value;
        const isContextSwitch = Boolean(this.initializedRecordContext) && this.initializedRecordContext !== contextKey;

        const existing = new Set();
        const loadedValues = this.extractUniqueTokens(rawValue, existing);
        const unsyncedLocalValues = isContextSwitch
            ? []
            : this.values.filter((value) => {
                  const normalized = value.toLowerCase();
                  if (existing.has(normalized)) {
                      return false;
                  }
                  existing.add(normalized);
                  return true;
              });

        this.values = [...loadedValues, ...unsyncedLocalValues];
        this.lastSavedContext = contextKey;
        this.lastSavedValue = loadedValues.join(';');
        this.initializedRecordContext = contextKey;

        if (isContextSwitch) {
            this.inputValue = '';
        }

        if (unsyncedLocalValues.length || this.pendingSync) {
            this.pendingSync = false;
            this.requestRecordSync();
        }
    }

    get resolvedCardTitle() {
        return this.cardTitle || 'Multi Input Pills';
    }

    get resolvedInputLabel() {
        return this.inputLabel || 'Add values';
    }

    get resolvedFieldApiName() {
        if (!this.fieldApiName) {
            return '';
        }

        return this.fieldApiName.trim().split('.').pop();
    }

    get resolvedFieldLabel() {
        const fieldName = this.resolvedFieldApiName;
        if (!fieldName) {
            return '';
        }

        const fieldDef = this.objectInfo?.data?.fields?.[fieldName];
        return fieldDef?.label || fieldName;
    }

    get recordContextKey() {
        if (!this.recordId || !this.resolvedFieldApiName) {
            return '';
        }

        return `${this.recordId}:${this.resolvedFieldApiName}`;
    }

    get recordFields() {
        if (!this.objectApiName || !this.resolvedFieldApiName) {
            return undefined;
        }

        return [`${this.objectApiName}.${this.resolvedFieldApiName}`];
    }

    get canPersistToRecord() {
        return Boolean(this.recordId && this.resolvedFieldApiName);
    }

    get canLoadExistingRecordValues() {
        return Boolean(this.objectApiName && this.canPersistToRecord);
    }

    get hasItems() {
        return this.values.length > 0;
    }

    get pillItems() {
        return this.values.map((value, index) => ({
            label: value,
            name: String(index)
        }));
    }

    handleInputChange(event) {
        this.inputValue = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' || event.key === ',') {
            event.preventDefault();
            this.commitCurrentInput(event.target.value);
        }
    }

    handleBlur(event) {
        this.commitCurrentInput(event.target.value);
    }

    handleItemRemove(event) {
        const index = Number(event.detail.item.name);

        if (!Number.isInteger(index)) {
            return;
        }

        this.values = this.values.filter((_, i) => i !== index);
        this.requestRecordSync();
    }

    commitCurrentInput(rawInput = this.inputValue) {

        if (!rawInput || !rawInput.trim()) {
            this.inputValue = '';
            return;
        }

        const existing = new Set(this.values.map((value) => value.toLowerCase()));
        const toAdd = this.extractUniqueTokens(rawInput, existing);

        if (toAdd.length) {
            this.values = [...this.values, ...toAdd];
            this.requestRecordSync();
        }

        this.inputValue = '';
    }

    requestRecordSync() {
        if (!this.canPersistToRecord) {
            return;
        }

        if (this.canLoadExistingRecordValues && this.initializedRecordContext !== this.recordContextKey) {
            this.pendingSync = true;
            return;
        }

        if (this.isSaving) {
            this.pendingSync = true;
            return;
        }

        void this.syncRecordField();
    }

    async syncRecordField() {
        if (!this.canPersistToRecord) {
            return;
        }

        const contextKey = this.recordContextKey;
        const fieldName = this.resolvedFieldApiName;
        const serializedValues = this.values.join(';');

        if (this.lastSavedContext !== contextKey) {
            this.lastSavedContext = contextKey;
            this.lastSavedValue = '';
        }

        if (serializedValues === this.lastSavedValue) {
            return;
        }

        const fields = {
            Id: this.recordId
        };
        fields[fieldName] = serializedValues;

        this.isSaving = true;
        try {
            await updateRecord({ fields });

            if (this.recordContextKey === contextKey) {
                this.lastSavedContext = contextKey;
                this.lastSavedValue = serializedValues;
                this.showToast('Record Updated', `${this.resolvedFieldLabel} was updated successfully.`, 'success');
            }
        } catch (error) {
            this.showToast(
                'Update Failed',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isSaving = false;

            if (this.pendingSync) {
                this.pendingSync = false;
                this.requestRecordSync();
            }
        }
    }

    extractUniqueTokens(rawValue, existing = new Set()) {
        const input = typeof rawValue === 'string' ? rawValue : '';

        return input
            .split(/[,\n;]/)
            .map((token) => token.trim())
            .filter(Boolean)
            .filter((token) => {
                const normalized = token.toLowerCase();
                if (existing.has(normalized)) {
                    return false;
                }

                existing.add(normalized);
                return true;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (Array.isArray(error?.body) && error.body.length && error.body[0]?.message) {
            return error.body[0].message;
        }

        return 'An unexpected error occurred while updating the record.';
    }
}