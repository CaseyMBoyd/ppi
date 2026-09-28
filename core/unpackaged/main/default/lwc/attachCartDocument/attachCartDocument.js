/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { api, wire } from "lwc";
import { CheckoutComponentBase } from "commerce/checkoutApi";
import { CartSummaryAdapter } from "commerce/cartApi";
import { refreshApex } from "@salesforce/apex";
import { CheckoutStage } from "c/b2bUtils";

import createCartDocument from "@salesforce/apex/CartDocumentUploadController.createCartDocument";
import fetchCartDocuments from "@salesforce/apex/CartDocumentUploadController.fetchCartDocuments";
import deleteCartDocument from "@salesforce/apex/CartDocumentUploadController.deleteCartDocument";
import ToastContainer from "lightning/toastContainer";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import canCheckoutPermission from '@salesforce/customPermission/Can_Checkout';

function readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
        const fr = new FileReader();
        fr.onload = () => {
            const mimeTypeStripedContent = fr.result.split(",").pop();
            resolve(mimeTypeStripedContent);
        };
        fr.onerror = reject;
        fr.readAsDataURL(file);
    });
}

export default class AttachCartDocument extends CheckoutComponentBase {
    @api required;
    @api label;
    @api acceptedFormats;
    @api allowMultiple;

    @api errorFileUploadIsRequired = "File upload is required";
    @api errorFailedToAttach = "There was an issue attaching your file.";
    @api errorFailedToDelete = "We were unable to remove this file.";

    @wire(fetchCartDocuments, { cartId: "$cartId" })
    wiredAttachedFiles;

    @wire(CartSummaryAdapter)
    cartSummary;

    isLoading;
    isSummary;

    get cartId() {
        return this.cartSummary?.data?.cartId;
    }

    get attachedFiles() {
        return this.wiredAttachedFiles?.data || [];
    }

    get canCheckout() {
        return canCheckoutPermission;
    }

    @api
    setAspect(newAspect) {
        this.isSummary = newAspect.summary;
    }

    get acceptedFormatsLabel(){
        return `Accepted formats are: ${this.acceptedFormats}`
    }

    @api
    async stageAction(checkoutStage) {
        switch (checkoutStage) {
            case CheckoutStage.REPORT_VALIDITY_SAVE:
                return Promise.resolve(this.reportValidity());
            default:
                return Promise.resolve(true);
        }
    }

    reportValidity() {
        const validityMessage =
            this.required && !this.attachedFiles.length
                ? this.errorFileUploadIsRequired
                : "";

        this.refs.fileInput.setCustomValidity(validityMessage);
        return this.refs.fileInput.reportValidity();
    }

    async connectedCallback() {
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = "top-center";

        await this.dispatchRequestAspect({
            summarizable: false,
            uneditable: false,
        });
    }

    async handleUploadFinished(event) {
        event.preventDefault();
        event.stopPropagation();

        this.isLoading = true;

        try {
            await Promise.all(
                Array.from(event.target.files).map(
                    this.uploadAttachment.bind(this)
                )
            );
            await refreshApex(this.wiredAttachedFiles);
            this.reportValidity();
        } catch (err) {
            this.dispatchEvent(
                new ShowToastEvent({
                    variant: "error",
                    title: "Error",
                    message: this.errorFailedToAttach,
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    async uploadAttachment(file) {
        const base64content = await readFileAsBase64(file);

        const fileInput = {
            base64content,
            cartId: this.cartId,
            name: file.name,
            mimeType: file.type,
        };

        await createCartDocument({ fileInput });
    }

    async deleteCartDocument(event) {
        const { cartDocumentId } = event.target.dataset;
        this.isLoading = true;

        try {
            await deleteCartDocument({ cartDocumentId });
            await refreshApex(this.wiredAttachedFiles);
            this.reportValidity();
        } catch (err) {
            this.dispatchEvent(
                new ShowToastEvent({
                    variant: "error",
                    title: "Error",
                    message: this.errorFailedToDelete,
                })
            );
        } finally {
            this.isLoading = false;
        }
    }
}