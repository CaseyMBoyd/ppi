/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { api, track, wire } from "lwc";
import { CheckoutStage } from "c/b2bUtils";
import { CheckoutComponentBase } from "commerce/checkoutApi";

import getShipDateDaysAvailable from "@salesforce/apex/CheckoutController.getShipDateDaysAvailable";
import fetchShippingBlackoutDates from "@salesforce/apex/CheckoutController.fetchShippingBlackoutDates";
import saveShipDateInformation from "@salesforce/apex/CheckoutController.saveShipDateInformation";

import { labels } from "./labels";
import { auraExceptionHandler } from "c/auraExceptionHandler";

export default class CheckoutShipDate extends CheckoutComponentBase {
    date;
    selectedShipMethod = "Standard";
    isSummary = false;
    isLoading = false;

    @track values = {
        standard: true,
        noLater: false,
        noBefore: false,
    };

    @track blackoutDates = [];

    handleBlackoutDaysCallback = this.handleBlackoutDays.bind(this);

    async connectedCallback() {
        await this.dispatchRequestAspect({
            summarizable: false,
            uneditable: false,
        });
    }

    @api
    setAspect(newAspect) {
        this.isSummary = newAspect.summary;
    }

    @api
    async stageAction(checkoutStage) {
        switch (checkoutStage) {
            case CheckoutStage.REPORT_VALIDITY_SAVE:
                if(this.checkValidity()) {
                    return (await this.saveShipDateInformation())
                }
                return false;
            default:
                return Promise.resolve(true);
        }
    }

    @wire(fetchShippingBlackoutDates)
    blackoutDatesAdapter;

    handleBlackoutDays(date) {
        const blackoutDates = this.blackoutDatesAdapter?.data || [];
        return !blackoutDates.includes(date);
    }

    checkValidity() {
        return Array.from(this.template.querySelectorAll("c-date-picker")).reduce((isValid, el) => {
            return isValid && el.reportValidity();
        }, true);
    }

    async saveShipDateInformation() {
        this.isLoading = true;

        try {
            await saveShipDateInformation({
                option: this.selectedShipMethod,
                shipDate: this.date,
            });
            return true;
        }
        catch(err) {
            auraExceptionHandler.logAuraException(err);
            await this.dispatchUpdateErrorAsync({
                groupId: "ShippingError",
                type: "/commerce/errors/checkout-failure",
                exception: "Unable to save shipping information",
            });
            return false;
        }
        finally {
            this.isLoading = false;
        }
    }

    @wire(getShipDateDaysAvailable)
    daysAvailable;

    get today() {
        const today = new Date();
        return today.toISOString().split("T")[0];
    }

    get blockNoLaterThenCalendar() {
        return this.isSummary || !this.values.noLater;
    }

    get requiredDateForNoLaterDate() {
        return this.values.noLater;
    }

    get blockNoShipBeforeCalendar() {
        return this.isSummary || !this.values.noBefore;
    }

    get requiredDateForNoShipBeforeDate() {
        return this.values.noBefore;
    }

    get maxDate() {
        return this.calculateMaxDate();
    }

    get labels() {
        return labels;
    }

    handleRadioButtonChange(evt) {
        Object.keys(this.values).forEach((key) => {
            this.values[key] = key === evt.target.dataset.key;
        });

        this.selectedShipMethod = evt.target.dataset.value;
        this.template.querySelectorAll("c-date-picker").forEach((element) => {
            element.reset();
        });
    }

    calculateMaxDate() {
        if (this.daysAvailable.data) {
            const today = new Date();
            const daysLaterAvailable = new Date();
            daysLaterAvailable.setDate(
                today.getDate() + this.daysAvailable.data
            );

            return daysLaterAvailable.toISOString().split("T")[0];
        }

        this.template.querySelectorAll(".date-picker").forEach((element) => {
            if (element.hasAttribute("max")) {
                element.removeAttribute("max");
            }
        });

        return 0;
    }

    handleDateChange(event) {
        this.date = event.detail.value;
    }
}