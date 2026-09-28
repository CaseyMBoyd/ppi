/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/forefront
 * @date 22.10.2024
 *
 **/

import { api, LightningElement, wire } from "lwc";
import { getFieldValue, getRecord } from "lightning/uiRecordApi";

import XA_INTEGRATED from "@salesforce/schema/Order.Integrated__c";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";
import { auraExceptionHandler } from "c/auraExceptionHandler";

import {
    notifyRecordUpdateAvailable,
} from "lightning/uiRecordApi";

import sendOrderToXa from "@salesforce/apex/SendOrderToXaController.sendOrderToXa";

const FIELDS = [XA_INTEGRATED];

export default class QuickActionSendOrderToXa extends LightningElement {
    isLoading = false;

    @api recordId;

    @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
    orderRecord;

    @api async invoke() {
        if (getFieldValue(this.orderRecord.data, XA_INTEGRATED)) {
            const confirm = await LightningConfirm.open({
                message:
                    "This order appears to have already been integrated with XA. Are you sure you want to send it again?",
                label: "Confirm re-integration",
                theme: "warning",
                primaryButtonLabel: "Send",
                secondaryButtonLabel: "Cancel",
            });

            if (!confirm) {
                return;
            }
        }

        try {
            this.isLoading = true;
            const success = await sendOrderToXa({ orderId: this.recordId });

            if (success) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Success",
                        message: "Order Successfully sent to XA!",
                        variant: "success",
                    })
                );

                await notifyRecordUpdateAvailable([{recordId: this.recordId}]);
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Error",
                        message: "Error Sending your Order!",
                        variant: "error",
                    })
                );
            }
        } catch (err) {
            auraExceptionHandler.logAuraException(err);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Error Sending your Order!",
                    variant: "error",
                })
            );
        }
        finally {
            this.isLoading = false;
        }
    }
}