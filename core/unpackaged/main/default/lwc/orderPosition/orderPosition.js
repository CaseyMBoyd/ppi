/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */


import {api, LightningElement} from 'lwc';
import ReorderModal from "c/reorderModal";
import {NavigationMixin} from "lightning/navigation";
import ToastContainer from "lightning/toastContainer";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import basePath from "@salesforce/community/basePath";
import {auraExceptionHandler} from "c/auraExceptionHandler";

export default class OrderPosition extends NavigationMixin(LightningElement) {
    @api order;

    connectedCallback() {
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = "top-center";
    }

    async handleReorder() {
        const response = await ReorderModal.open({
            size: 'small',
            orderSummaryId: this.order.Id
        });

        if(response.result === 'viewcart') {
            window.location = basePath + '/cart';
        } else if(response.result === 'error') {
            auraExceptionHandler.logAuraException(response.error);
            this.dispatchEvent(
                new ShowToastEvent({
                    message: "Error",
                    title: "We were unable to reorder. Please try again later.",
                    variant: "error",
                })
            );
        }
    }

    handleViewDetails() {
        window.location = basePath + '/OrderSummary/' + this.order.Id;
    }

}