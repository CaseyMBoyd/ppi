/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { api, LightningElement } from 'lwc';

export default class AddToCartWithBushings extends LightningElement {
    @api bushings = [];
    @api productId;

    selectedBushing = '';

    handleBushingChange(event) {
        this.selectedBushing = event.detail?.bushingId;
    }
}