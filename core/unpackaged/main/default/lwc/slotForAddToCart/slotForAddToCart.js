/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */


import {api, track, wire, LightningElement} from 'lwc';
import {isInSitePreview} from "c/b2bUtils";
import { auraExceptionHandler } from "c/auraExceptionHandler";

import getBushings from '@salesforce/apex/ProductController.getBushingsForProduct';

/**
 * @slot slotForAddToCartWithoutBushings
 */
export default class SlotForAddToCart extends LightningElement {
    @api recordId;

    get bushingsExist() {
        return this.bushings.length > 0 || isInSitePreview();
    }

    get bushingsEmpty() {
        return this.bushings.length === 0 || isInSitePreview();
    }

    @track bushings = [];

    @wire(getBushings, {productId: '$recordId'})
    wiredBushings({error, data}) {
        if (data) {
            this.bushings = data;
        } else if (error) {
           auraExceptionHandler.logAuraException(error);
        }
    }
}