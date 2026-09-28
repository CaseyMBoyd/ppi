/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { LightningElement } from 'lwc';
import canCheckoutPermission from '@salesforce/customPermission/Can_Checkout';
import isCartEmpty from '@salesforce/apex/CartController.isCartEmpty';
import { NavigationMixin } from "lightning/navigation";

export default class CheckoutButton extends NavigationMixin(LightningElement) {

    cartIsEmpty = true;

    connectedCallback() {
        isCartEmpty()
            .then(result => {
                this.cartIsEmpty = result;
            })
            .catch(error => console.error('Error checking cart status', error));
    }

    get canCheckout() {
        return !this.cartIsEmpty && canCheckoutPermission;
    }

    handleCheckout() {
        // Handle checkout logic
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/checkout',
            },
        });
    }
}