/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { LightningElement, api } from "lwc";

export default class DropdownInput extends LightningElement {
    @api options = [];
    @api placeholder;
    @api label;
    @api required;
    @api disabled;
    @api validityErrorMessage;

    showError = false;

    @api get value() {
        return this.selected;
    }

    set value(value) {
        this.selected = value;
    }

    selected;

    @api reportValidity() {
        const isValid = this.required ? this.selected : true;
        this.showError = !isValid;

        return isValid;
    }

    get searchClass() {
        return this.showError
            ? "search slds-has-error"
            : "search";
    }

    // CRM-4423: maps options adding computed class + disabled attribute.
    // Backward compatible: options without a `disabled` flag render exactly as before.
    get displayOptions() {
        return (this.options || []).map(option => ({
            ...option,
            itemClass: option.disabled
                ? 'dropdown-item dropdown-item--disabled'
                : 'dropdown-item',
            disabledAttr: option.disabled ? 'true' : 'false'
        }));
    }

    handleInputChange(event) {
        event.stopPropagation();
        this.selected = event.target.value;
        this.dispatchEvent(
            new CustomEvent("change", { detail: { value: this.selected } })
        );
    }

    handleOptionClicked(event) {
        event.stopPropagation();
        // CRM-4423: ignore clicks on disabled options
        if (event.currentTarget.dataset.disabled === 'true') {
            return;
        }
        this.selected = event.target.dataset.value;
    }
}