/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { LightningElement, api, track, wire } from 'lwc';
import fetchInventory from "@salesforce/apex/InventoryServiceB2B.getBulkInventoryStatus";
import getProductCategoryName from '@salesforce/apex/InventoryServiceB2B.getProductCategoryName';


export default class ProductInventory extends LightningElement {

    isLoading = true;
    productCategory;
    _recordId;

    @track inventories = [];


    @api
    get recordId() {
        return this._recordId;
    }

    @wire(getProductCategoryName, {recordId: '$recordId'})
    CategoryName({ error, data }) {
        if (data) {
            this.productCategory = data;
        } else if (error) {
            console.error(error);
        }
    }

    set recordId(value) {
        this._recordId = value;
        if (this._recordId) {
            this.fetchInventories();
        }
    }


    get hasInventories() {
        return this.inventories && this.inventories.length > 0;
    }


    async fetchInventories() {

        try {

            this.isLoading = true;

            const data = await fetchInventory({
                productId: this.recordId
            });

            this.inventories = (data || []).map((item, index) => ({
                id: index,
                warehouse: {
                    name: item.locationDisplayName,
                    code: item.warehouseCode
                },
                quantity: item.quantityAvailable
            }));

        } catch (error) {
            console.error('Inventory Error:',error);
            this.inventories = [];
        } finally {
            this.isLoading = false;
        }
    }
}