/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import LightningModal from 'lightning/modal';
import {api} from "lwc";

import updateCartNames from '@salesforce/apex/CartController.updateCartNames';
import ToastContainer from "lightning/toastContainer";
import {ShowToastEvent} from "lightning/platformShowToastEvent";
import {auraExceptionHandler} from "c/auraExceptionHandler";

export default class RenameCartModal extends LightningModal {
    isLoading = false;
    _cartName = '';

    @api cartId;

    @api
    get cartName() {
        return this._cartName;
    }

    set cartName(value) {
        this._cartName = value;
    }

    initialCartName = this.cartName;

    connectedCallback() {
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = "top-center";
    }

    get cartNameChanged() {
        return this._cartName !== this.initialCartName;
    }

    get disableSave() {
        return !this.cartNameChanged || this._cartName === '';
    }

    handleChange(event) {
        this._cartName = event.target.value;
    }

    async handleRenameCart() {
        this.isLoading = true;

        try {
            await updateCartNames({carts: [{Id: this.cartId, Name: this._cartName}]});

            this.dispatchEvent(
                new ShowToastEvent({
                    message: "Success",
                    title: `Cart Name updated.`,
                    variant: "success",
                })
            );

            this.close(true);
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    message: "Error",
                    title: `We were unable to update cart name, please try again later.`,
                    variant: "error",
                })
            );

            auraExceptionHandler.logAuraException(error);
        } finally {
            this.isLoading = false;
        }
    }

    closeModal() {
        this.close(false);
    }

}