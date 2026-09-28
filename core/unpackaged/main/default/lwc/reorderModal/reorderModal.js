/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import LightningModal from 'lightning/modal';
import {startReOrder} from 'commerce/orderApi';
import {api} from "lwc";

export default class ReorderModal extends LightningModal {
    isLoading = false;
    @api orderSummaryId;

    connectedCallback() {
        this.isLoading = true;

        startReOrder({cartStateOrId: 'current', orderSummaryId: this.orderSummaryId})
            .then(() => {
                this.isLoading = false;
            })
            .catch((error) => {
                this.close({result: 'error', error: error});
            }).finally(() => {
                this.isLoading = false;
            }
        )
    }

    handleViewCart() {
        this.close({result: 'viewcart', error: null});
    }

    handleContinueShopping() {
        this.close({result: 'continueshopping', error: null});
    }
}