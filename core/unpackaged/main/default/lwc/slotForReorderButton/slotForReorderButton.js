/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */


import {api, LightningElement, wire} from 'lwc';
import isReorderPossible from '@salesforce/apex/OrderController.isReorderPossible';
import {isInSitePreview} from "c/b2bUtils";

/**
 * @slot slotForReorderButton
 */
export default class SlotForReorderButton extends LightningElement {

    @api recordId;

    @wire(isReorderPossible, {orderSummaryId: '$recordId'})
    isReorderPossible;

    get reorderPossible() {
        return this.isReorderPossible.data || isInSitePreview();
    }

}