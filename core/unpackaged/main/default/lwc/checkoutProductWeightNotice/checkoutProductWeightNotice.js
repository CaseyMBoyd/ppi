/* Copyright (c) 2023 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { LightningElement, wire, api } from "lwc";
import { CartItemsAdapter } from "commerce/cartApi";
import { auraExceptionHandler } from "c/auraExceptionHandler";

export default class CheckoutProductWeightNotice extends LightningElement {
    totalWeight;
    @api label;

    @wire(CartItemsAdapter)
    cartItemAdapter({ error, data }) {
        if (data) {
            this.totalWeight = (data.cartItems || []).reduce((sum, item) => {
                const weight =
                    parseFloat(
                        item.cartItem?.productDetails?.fields?.Weight__c
                    ) || 0;
                const quantity = parseInt(item.cartItem?.quantity, 10) || 0;
                return sum + weight * quantity;
            }, 0);
        } else if (error) {
            auraExceptionHandler.logAuraException(error);
        }
    }

    get hasWeight() {
        return !!this.totalWeight;
    }
}