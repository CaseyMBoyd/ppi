/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */


import {api, track, LightningElement, wire} from 'lwc';
import {ProductAdapter} from "commerce/productApi";
import {auraExceptionHandler} from "c/auraExceptionHandler";
import getCustomerPartNumberForProduct from "@salesforce/apex/CustomerPartNumberController.getCustomerPartNumberForProduct";
import {getSessionContext} from "commerce/contextApi";

export default class OrderItemPosition extends LightningElement {
    @api orderItem;

    @track product = {};
    customerPartNumber; // CRM-4420

    connectedCallback() {
        this.resolveCustomerPartNumber();
    }

    // CRM-4420: resolve the customer part number for this order line (non-blocking).
    async resolveCustomerPartNumber() {
        try {
            const sessionContext = await getSessionContext();
            const accountId = sessionContext?.effectiveAccountId;
            const productId = this.orderItem?.Product2Id;
            if (!accountId || !productId) {
                return;
            }
            const customerPN = await getCustomerPartNumberForProduct({
                productId,
                accountId,
            });
            this.customerPartNumber = customerPN || undefined;
        } catch (e) {
            auraExceptionHandler.logAuraException(e);
        }
    }

    get imageUrl() {
        return this.product?.defaultImage?.url ?? '/sfsites/c/file-asset-public/product_placeholder';
    }

    get productUrl() {
        return `/product/detail/${this.product?.id}`;
    }

    @wire(ProductAdapter, {productId: "$orderItem.Product2Id"})
    wiredProduct({error, data}) {
        if(data) {
            this.product = data;
        } else if(error) {
            auraExceptionHandler.logAuraException(error);
        }
    }
}