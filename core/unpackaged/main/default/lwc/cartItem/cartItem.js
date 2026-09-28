/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { LightningElement, wire, track, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, updateRecord } from "lightning/uiRecordApi";

import { createCartItemUpdateAction, dispatchActionAsync } from "commerce/actionApi";
import { deleteItemFromCart } from "commerce/cartApi";

import cartChanged from "@salesforce/messageChannel/lightning__commerce_cartChanged";
import { MessageContext, publish } from "lightning/messageService";

import FIELD_CART_ITEM_NOTES from "@salesforce/schema/CartItem.Notes__c";
import FIELD_CART_ITEM_QUANTITY from "@salesforce/schema/CartItem.Quantity";
import FIELD_CART_ITEM_ID from "@salesforce/schema/CartItem.Id";
import getCustomerPartNumberForProduct from "@salesforce/apex/CustomerPartNumberController.getCustomerPartNumberForProduct";
import { getSessionContext } from "commerce/contextApi";

const formatCurrency = (currency, value) => {
    return new Intl.NumberFormat("en-US", {
        style: "currency",
        currency,
    }).format(value);
};

export default class CartItem extends NavigationMixin(LightningElement) {
    @api item;

    @track normalizedItem;

    @wire(MessageContext)
    messageContext;

    isLoading = false;
    notesMaxLength = 1000;
    customerPartNumber = null; // CRM-4420

    get itemId() {
        return this.item?.id;
    }

    quantity;

    @wire(getRecord, {
        recordId: "$itemId",
        fields: [FIELD_CART_ITEM_NOTES, FIELD_CART_ITEM_QUANTITY],
    })
    onItemNotesFetch({ error, data }) {
        if (data && this.item) {
            const discount = parseFloat(this.item.itemizedAdjustmentAmount);

            this.quantity = localStorage.getItem(this.itemId)
                ? parseInt(localStorage.getItem(this.itemId), 10)
                : this.item.quantity;

            localStorage.removeItem(this.itemId);

            this.normalizedItem = {
                ...this.item,
                notes: data.fields.Notes__c?.value,
                hasDiscount: !!discount,
                discount,
                savedAmountLabel: `Saved ${formatCurrency(
                    this.item.currencyIsoCode || "USD",
                    -discount
                )}`,
                productId: this.item.ProductDetails?.productId,
            };

            // CRM-4420: resolve customer part number and auto-fill the Line Item Tag if empty.
            this.resolveCustomerPartNumber(data.fields.Notes__c?.value);
        } else if (error) {
            console.error(error);
        }
    }

    // CRM-4420: non-blocking resolution of the customer part number.
    async resolveCustomerPartNumber(existingNotes) {
        try {
            const sessionContext = await getSessionContext();
            const accountId = sessionContext?.effectiveAccountId;
            const productId = this.item?.ProductDetails?.productId;
            if (!accountId || !productId) {
                return;
            }
            const customerPN = await getCustomerPartNumberForProduct({
                productId,
                accountId,
            });
            if (!customerPN) {
                return;
            }
            this.customerPartNumber = customerPN;
            this.normalizedItem = { ...this.normalizedItem, customerPartNumber: customerPN };

            // Auto-populate Notes__c (Line Item Tag) only when currently empty.
            if (!existingNotes) {
                await updateRecord({
                    fields: {
                        [FIELD_CART_ITEM_ID.fieldApiName]: this.itemId,
                        [FIELD_CART_ITEM_NOTES.fieldApiName]: customerPN,
                    },
                });
                this.normalizedItem = { ...this.normalizedItem, notes: customerPN };
            }
        } catch (e) {
            // Cart must render normally even if resolution fails.
            console.error("Customer PN resolution error:", e);
        }
    }

    async updateLineNotes(event) {
        const lineNotes = event.target.value;
        this.isLoading = true;

        try {
            await updateRecord({
                fields: {
                    [FIELD_CART_ITEM_ID.fieldApiName]: this.itemId,
                    [FIELD_CART_ITEM_NOTES.fieldApiName]: lineNotes,
                },
            });
        } catch (err) {
            console.error(err);
        } finally {
            this.isLoading = false;
        }
    }

    async updateQty(event) {
        const quantity = event.detail.value;
        this.isLoading = true;

        try {
            localStorage.setItem(this.itemId, quantity);
            await dispatchActionAsync(this, createCartItemUpdateAction(this.itemId, quantity));
        } catch (err) {
            console.error(err);
        } finally {
            this.isLoading = false;
        }
    }

    async deleteLine() {
        this.isLoading = true;

        try {
            await deleteItemFromCart(this.itemId);
            publish(this.messageContext, cartChanged);
        } catch (err) {
            console.error(err);
        } finally {
            this.isLoading = false;
        }
    }

    goToPDP(event) {
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: event.target.dataset.id,
                objectApiName: "Product2",
                actionName: "view",
            },
        });
    }
}