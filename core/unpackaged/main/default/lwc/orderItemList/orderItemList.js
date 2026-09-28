/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */


import {api, LightningElement, track, wire} from 'lwc';

import getOrderItems from '@salesforce/apex/OrderController.getOrderItemSummaries';
import getDeliveryMethod from '@salesforce/apex/OrderController.getOrderDeliveryMethod';
import {auraExceptionHandler} from "c/auraExceptionHandler";
import {resolvePath} from "c/utils";

export default class OrderItemList extends LightningElement {
    address = '';
    shippingMethodName = '';

    @api recordId;
    @api fieldsJson;

    @track deliveryMethod = {};
    @track orderItems = [];
    @track defaultActiveSection = [];

    get accordionSectionLabel() {
        return `Ship To: ${this.address}` ?? '';
    }

    get fieldsArray() {
        return JSON.parse(this.fieldsJson).map(field => {
            return field.field;
        });
    }

    @wire(getOrderItems, {orderSummaryId: '$recordId', fields: '$fieldsArray'})
    wiredOrderItemSummaries({error, data}) {
        if (data) {
            this.orderItems = data.map(item => {
                return {
                    ...item,
                    displayFields: JSON.parse(this.fieldsJson).map(field => {
                        return {...field, value: resolvePath(field.field, item) ?? ''}
                    })
                }
            });
        } else if (error) {
            auraExceptionHandler.logAuraException(error);
        }
    }

    @wire(getDeliveryMethod, {orderSummaryId: '$recordId'})
    wiredDeliveryMethod({error, data}) {
        if (data) {
            this.shippingMethodName = data.shippingMethodName;
            this.address = `${data.orderDeliveryGroup.DeliverToName ?? ''}, ${data.orderDeliveryGroup.DeliverToStreet ?? ''}, ${data.orderDeliveryGroup.DeliverToCity ?? ''}, ${data.orderDeliveryGroup.DeliverToState ?? ''} ${data.orderDeliveryGroup.DeliverToPostalCode ?? ''}, ${data.orderDeliveryGroup.DeliverToCountry ?? ''}`
        } else if (error) {
            auraExceptionHandler.logAuraException(error);
        }
    };

    handleSectionToggle(event) {
        this.defaultActiveSection = event.detail.openSections;
    }
}