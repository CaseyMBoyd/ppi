/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */


import {api, LightningElement} from 'lwc';
import basePath from "@salesforce/community/basePath";

import {auraExceptionHandler} from "c/auraExceptionHandler";
import {addItemToCart} from "commerce/cartApi";
import ToastContainer from "lightning/toastContainer";
import {ShowToastEvent} from "lightning/platformShowToastEvent";

import addToCartModal from "c/pdpAddToCartModal";
import bushingsModal from "c/bushingsModal";

export default class PdpAddToCartButtonWithQtySelector extends LightningElement {
    @api incrementStep = 1;
    @api productId;
    @api bushings;
    selectedBushing;

    quantity = 1;

    get buttonDisabled() {
        return this.quantity === 0;
    }

    connectedCallback() {
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = "top-center";
    }

    handleQtyChange(e) {
        this.quantity = e.detail.value;
    }

    async addToCartAction() {
        if(this.bushings?.length > 0) {
            const result = await bushingsModal.open({
                size: 'small',
                bushings: this.bushings,
                onbushingchange: (e) => this.selectedBushing = e.detail.bushingId,
            });
            if(result === 'add') {
                await this.handleAddToCart();
            }
        } else {
            await this.handleAddToCart();
        }
    }

    async handleAddToCart() {
        try {
            await addItemToCart(this.productId, this.quantity);

            if(this.selectedBushing) {
                await addItemToCart(this.selectedBushing, this.quantity * 2);
            }

            const result = await addToCartModal.open({
                size: 'small'
            });

            if (result === 'cart') {
                window.location = basePath + '/cart';
            }
        } catch (err) {
            auraExceptionHandler.logAuraException(err);

            this.dispatchEvent(new ShowToastEvent({
                variant: "error",
                title: "Unable to add items to cart",
                message: "There was an issue adding items to cart, please try again later or contact the Administrator."
            }))
        }
    }
}