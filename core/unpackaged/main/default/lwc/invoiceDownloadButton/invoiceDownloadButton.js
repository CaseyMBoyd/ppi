/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import {LightningElement, api, wire} from 'lwc';
import {getFieldValue, getRecord} from "lightning/uiRecordApi";

import FIELD_ORDER_EXTERNAL_ID from "@salesforce/schema/OrderSummary.Order_External_Id__c";

import fetchInvoice from "@salesforce/apex/XaCalloutController.fetchInvoice";
import ToastContainer from "lightning/toastContainer";
import {ShowToastEvent} from "lightning/platformShowToastEvent";

/**
 * @slot content
 */
export default class InvoiceDownloadButton extends LightningElement {
    @api recordId;

    @wire(getRecord, {
        recordId: "$recordId",
        fields: [FIELD_ORDER_EXTERNAL_ID],
    })
    wiredSummary;

    isLoading = false;

    connectedCallback() {
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = "top-center";
    }

    get orderExternalId() {
        return getFieldValue(this.wiredSummary?.data, FIELD_ORDER_EXTERNAL_ID);
    }

    get disabled() {
        return !this.orderExternalId;
    }

    async downloadInvoice() {
        this.isLoading = true;

        try {
            const base64pdf = await fetchInvoice({
                orderSummaryId: this.recordId,
            });
            const downloadLink = document.createElement("a");

            downloadLink.href = `data:application/pdf;base64,${base64pdf}`;
            downloadLink.download = `order-${this.orderExternalId}.pdf`;
            downloadLink.click();

        } catch (err) {
            console.error("unable to download invoice", err);

            this.dispatchEvent(new ShowToastEvent({
                variant: "error",
                title: "Unable to generate Invoice PDF",
                message: "There was an issue generating your PDF, please try again later or contact the Administrator."
            }))
        } finally {
            this.isLoading = false;
        }
    }
}