/* Copyright (c) 2021 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { LightningElement, wire, api, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";

import { ShowToastEvent } from "lightning/platformShowToastEvent";
import ToastContainer from "lightning/toastContainer";

import { labels } from "./labels.js";

import { addItemToCart } from "commerce/cartApi";

import { publish, MessageContext } from "lightning/messageService";
import cartChanged from "@salesforce/messageChannel/lightning__commerce_cartChanged";

import ProductInventoryModal from "c/productInventoryModal";
import bushingsModal from "c/bushingsModal";
import { auraExceptionHandler } from "c/auraExceptionHandler";
import getBushings from '@salesforce/apex/ProductController.getBushingsForProduct';
import getCustomerPartNumberForProduct from '@salesforce/apex/CustomerPartNumberController.getCustomerPartNumberForProduct';
import { getSessionContext } from "commerce/contextApi";
import { AppContextAdapter } from "commerce/contextApi";
import getPLPAvailability from "@salesforce/apex/SearchResultsControllerB2B.getPLPAvailability";

/**
 * name => Name
 * sku => StockKeepingUnit
 * description => Description
 * pretty description => Pretty_Description__c
 */

export default class ProductDetail extends NavigationMixin(LightningElement) {
    @api product;
    @api categoryId;
    @wire(MessageContext)
    messageContext;
    
    webStoreId;
    @wire(AppContextAdapter)
    wiredAppContext({ data, error }) {
        if (data) {
            this.webStoreId = data.webstoreId;
            this.loadInventoryAvailability();
        } else if (error) {
            auraExceptionHandler.logAuraException(error);
        }
    }

    @track quantity = 1;

    @track bushings = [];

    // ------------------------
    showTooltip = false;
    tooltipTimer;
    @track _inventoryStatus;

    get availabilityStatus() {
        if (this._inventoryStatus === undefined) {
            return 'Availability Loading';
        }
        const status = this._inventoryStatus?.availabilityStatus || 'Availability Unknown';
        // "Unknown" is a real ERP response (no data for this SKU), but customers
        // shouldn't see that distinction — treat it the same as Made to Order.
        return status === 'Availability Unknown' ? 'Made to Order' : status;
    }

    get availableQuantity() {
        return this._inventoryStatus?.availableQuantity ?? 0;
    }

    get warehouses() {
        return this._inventoryStatus?.warehouses || [];
    }

    get availabilityLabel() {
        if (this.availabilityStatus === 'Availability Loading') {
            return 'Availability Loading';
        }

        if (this.availabilityStatus === 'Low Stock') {
            return 'Low Stock — Only ' + this.availableQuantity + ' in stock';
        }

        if (this.availabilityStatus === 'In Stock') {
            return 'In Stock — Hover for typical lead times';
        }

        if (this.availabilityStatus === 'Made to Order') {
            return 'Made to Order';
        }

        return 'Availability Unknown';
    }

    get availabilityBadgeClass() {
        const baseClass = 'availability-badge ';

        if (this.availabilityStatus === 'In Stock') {
            return baseClass + 'badge-in-stock';
        }

        if (this.availabilityStatus === 'Low Stock') {
            return baseClass + 'badge-low-stock';
        }

        if (this.availabilityStatus === 'Made to Order') {
            return baseClass + 'badge-made-to-order';
        }

        return baseClass + 'badge-unknown';
    }

    get showInventoryTooltip() {
        return this.showTooltip &&
            this.availabilityStatus !== 'Availability Unknown' &&
            this.availabilityStatus !== 'Availability Loading';
    }

    handleTooltipMouseOver() {
        window.clearTimeout(this.tooltipTimer);

        this.tooltipTimer = window.setTimeout(() => {
            this.showTooltip = true;
        }, 300);
    }

    handleTooltipMouseOut() {
        window.clearTimeout(this.tooltipTimer);
        this.showTooltip = false;
    }

    //-----------------------------
    get bushingsAvailable() {
        return this.bushings.length > 0;
    }

    get recordId() {
        return this.product.sfid;
    }

    @wire(getBushings, { productId: '$recordId' })
    wiredBushings({ error, data }) {
        if (data) {
            this.bushings = data;
        } else if (error) {
            auraExceptionHandler.logAuraException(error);
        }
    }

    isLoading = false;
    errorText;

    // CRM-4420
    customerPartNumber = null;

    connectedCallback() {
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = "top-center";

        this.resolveCustomerPartNumber();
    }

    // CRM-4420: resolve the customer part number for this product.
    // Non-blocking: the card renders normally if resolution fails.
    async resolveCustomerPartNumber() {
        try {
            const sessionContext = await getSessionContext();
            if (!sessionContext?.effectiveAccountId || !this.product?.sfid) {
                return;
            }
            const customerPN = await getCustomerPartNumberForProduct({
                productId: this.product.sfid,
                accountId: sessionContext.effectiveAccountId,
            });
            this.customerPartNumber = customerPN || null;
        } catch (error) {
            auraExceptionHandler.logAuraException(error);
        }
    }

    async loadInventoryAvailability() {
        const sku = this.product?.fields?.StockKeepingUnit;
        if (!sku || !this.webStoreId) {
            return;
        }
        
        this.isInventoryLoading = true;
        try {
            const result = await getPLPAvailability({
                productCodes: [sku],
                categoryId: this.categoryId || null,
                webStoreId: this.webStoreId
            });
            this._inventoryStatus = result?.[sku] || null;
        } catch (error) {
            auraExceptionHandler.logAuraException(error);
        } finally {
            this.isInventoryLoading = false;
        }
        
    }

    get qty() {
        return this.quantity;
    }

    get labels() {
        return labels;
    }

    get showPricing() {
        return this.product?.prices?.listPrice != null && Number(this.product?.prices?.listPrice) > 0;
    }

    get showStrikethrough() {
        return Number(this.product?.prices?.unitPrice) < Number(this.product?.prices?.listPrice);
    }

    get showContact() {
        return Number(this.product?.prices?.listPrice) <= 0;
    }

    goToPDP() {
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: this.recordId,
                objectApiName: "Product2",
                actionName: "view",
            },
        });
    }

    async addToCartAction() {
        if (this.bushingsAvailable) {
            let selectedBushing;
            const result = await bushingsModal.open({
                size: 'small',
                bushings: this.bushings,
                onbushingchange: (e) => {
                    selectedBushing = e.detail.bushingId;
                },
            });

            if (result === 'add') {
                await this.addToCart(selectedBushing);
            }
        } else {
            await this.addToCart();
        }
    }

    async addToCart(selectedBushing) {
        this.isLoading = true;

        try {
            await addItemToCart(this.product.sfid, this.quantity);

            if (selectedBushing) {
                await addItemToCart(selectedBushing, this.quantity * 2);
            }

            const toast = new ShowToastEvent({
                title: "Add To Cart",
                message: `Successfully added ${this.product.fields.Name} to cart`,
                variant: "success",
            });
            this.dispatchEvent(toast);

            publish(this.messageContext, cartChanged);
        } catch (err) {
            const toast = new ShowToastEvent({
                title: "Add To Cart",
                message: `Failed to add ${this.product.name} to cart`,
                variant: "error",
            });
            this.dispatchEvent(toast);

        } finally {
            this.isLoading = false;
        }
    }

    async openProductInventoryModal() {
        await ProductInventoryModal.open({
            size: "small",
            recordId: this.product.sfid,
        });
    }

    updateQty(event) {
        const quantity = event.detail.value;
        this.quantity = parseInt(quantity);
    }
}