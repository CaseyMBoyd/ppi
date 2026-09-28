/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { api, wire } from "lwc";
import {
    simplePurchaseOrderPayment,
    CheckoutComponentBase,
    CheckoutInformationAdapter,
} from "commerce/checkoutApi";

import {getSessionContext} from "commerce/contextApi";
import fetchAccount from "@salesforce/apex/CheckoutController.fetchAccount";

import { CheckoutStage } from "c/b2bUtils";
import { NavigationMixin } from "lightning/navigation";

import canCheckoutPermission from '@salesforce/customPermission/Can_Checkout';

const KEY_CACHED_PO_NUMBER = "cachedPoNumber";

export default class CheckoutPoNumber extends NavigationMixin(CheckoutComponentBase) {

    poNumber;
    isSummary;

    @api label = "PO Number";
    @api maxLength = 50;
    @api checkoutDetails;

    @wire(CheckoutInformationAdapter)
    wiredCheckoutInformation;

    get checkoutId() {
        return this.checkoutDetails?.checkoutId;
    }

    get canCheckout() {
        return canCheckoutPermission;
    }

    @api
    async setAspect(newAspect) {
        this.poNumber = localStorage.getItem(KEY_CACHED_PO_NUMBER) || "";
        this.isSummary = newAspect.summary;
    }

    @api
    async stageAction(checkoutStage) {
        switch (checkoutStage) {
            case CheckoutStage.REPORT_VALIDITY_SAVE:
                return Promise.resolve(this.reportValidity());
            case CheckoutStage.BEFORE_PLACE_ORDER:
                return Promise.resolve(this.paymentProcess());
            case CheckoutStage.START_PAYMENT_SESSION:
                if(!this.checkoutDetails?.display?.complete) {
                    await this.dispatchUpdateErrorAsync({
                        groupId: "PlaceOrderError",
                        type: "/commerce/errors/checkout-failure",
                        exception: "Please fill out all sections."
                    });
                }

                return true;

            default:
                return Promise.resolve(true);
        }
    }

    reportValidity() {
        return this.refs.poNumber.reportValidity();
    }

    @api
    async paymentProcess() {
        if (!this.reportValidity()) {
            throw new Error('Required data is missing');
        }

        try {
            const context = await getSessionContext();
            const account = await fetchAccount({effectiveAccountId: context.effectiveAccountId});

            const billingAddress = {
                city: account.BillingCity,
                country: account.BillingCountryCode,
                postalCode: account.BillingPostalCode,
                region: account.BillingStateCode,
                street: account.BillingStreet,
            };

            await simplePurchaseOrderPayment(this.checkoutId, this.poNumber, billingAddress);
            localStorage.removeItem(KEY_CACHED_PO_NUMBER);
            return true;
        }
        catch(err) {
            await this.dispatchUpdateErrorAsync({
                groupId: "PlaceOrderError",
                type: "/commerce/errors/checkout-failure",
                exception: "Order Placement failed. Please try again or contact customer service."
            });
            return false;
        }
    }

    handlePoNumberChange(event) {
        this.poNumber = event.target.value;
        localStorage.setItem(KEY_CACHED_PO_NUMBER, this.poNumber);
    }
}