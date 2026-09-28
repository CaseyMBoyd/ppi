/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */


import {LightningElement, track} from 'lwc';
import getOrderSummaries from '@salesforce/apex/OrderController.getOrderSummaries';
import {auraExceptionHandler} from "c/auraExceptionHandler";
import {effectiveAccount} from "commerce/effectiveAccountApi";

export default class OrderList extends LightningElement {
    @track orders = [];

    get defaultEndDate() {
        return`${new Date().toISOString().split('T')[0]}T23:59:00.000Z`;
    }

    get defaultStartDate() {
        let d = new Date();
        d.setDate(d.getDate() - 1);

        return `${d.toISOString().split('T')[0]}T00:00:00.000Z`;
    }

    endDate = this.defaultEndDate;
    startDate = this.defaultStartDate;
    poNumber = '';
    dateChanged = false;
    limit = 25;
    isLoading = false;

    sortingOptions = [
        {label: 'Sort items by most recent order', value: 'DESC'},
        {label: 'Sort items by oldest order', value: 'ASC'}
    ];

    sortDirection = 'DESC';

    get ordersListSize() {
        return this.orders.length;
    }

    get showShowMore() {
        return this.orders.length === this.limit;
    }


    connectedCallback() {
        this.getOrderSummaries();
    }

    handleFromDateChange(event) {
        this.dateChanged = true;
        this.startDate = event.detail.value;
    }

    handleEndDateChange(event) {
        this.dateChanged = true;
        this.endDate = event.detail.value;
    }

    handlePoNumberChange(event) {
        this.poNumber = event.detail.value;
    }

    handleApplyFilters() {
        this.getOrderSummaries();
    }

    handleResetFilters() {
        this.poNumber = '';
        this.startDate = this.defaultStartDate;
        this.endDate = this.defaultEndDate;
        this.dateChanged = false;
        this.limit = 25;

        this.getOrderSummaries();
    }

    handleShowMore() {
        this.limit += 25;
        this.getOrderSummaries();
    }

    handleSortDirectionChange(event) {
        this.sortDirection = event.detail.value;
        this.getOrderSummaries();
    }

    getOrderSummaries() {
        this.isLoading = true;

        getOrderSummaries({
            filters: {
                startDate: this.dateChanged ? this.startDate : null,
                endDate: this.dateChanged ? this.endDate : null,
                PONumber: this.poNumber,
                effectiveAccountId: effectiveAccount.accountId
            },
            pageSize: this.limit,
            sortBy: 'OrderedDate',
            sortDirection: this.sortDirection
        })
            .then((res) => {
                this.orders = res.map(order => {
                    return {
                        ...order,
                        reorderDisabled: order.OrderItemSummaries && order.OrderItemSummaries.length !== 0
                    }
                });
            }).catch((err) => {
            auraExceptionHandler.logAuraException(err);
        }).finally(() => {
            this.isLoading = false;
        });
    }

}