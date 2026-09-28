/* Copyright (c) 2022 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */


import { auraExceptionHandler } from "c/auraExceptionHandler";

import LightningModal from 'lightning/modal';

import createPrimaryCart from "@salesforce/apex/CartController.createPrimaryCart";

import ToastContainer from "lightning/toastContainer";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import {api} from "lwc";

export default class NewCart extends LightningModal {

    cartName = "";
    isLoading = false;

    @api effectiveAccountId;

    connectedCallback() {
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = "top-center";
    }

    get invalidName() {
        return this.cartName.length === 0;
    }


    handleChange(event) {
        this.cartName = event.target.value;
    }

    createCart() {
        this.isLoading = true;
        createPrimaryCart({ cartName: this.cartName, accountId: this.effectiveAccountId })
            .then((res) => {
                this.fireNewCartEvent(res.cartId);

                this.dispatchEvent(
                    new ShowToastEvent({
                        message: "Success",
                        title: `Cart ${res.name} was created.`,
                        variant: "success",
                    })
                );
                this.close(true);
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        message: "Error",
                        title: `We were unable to create new cart at this time, please try again later.`,
                        variant: "error",
                    })
                );
                auraExceptionHandler.logAuraException(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    fireNewCartEvent(cartId) {
        const selectedEvent = new CustomEvent("create", {
            detail: { cartId },
        });
        this.dispatchEvent(selectedEvent);
    }

    closeModal() {
        this.close(false);
    }
}