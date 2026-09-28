/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */


import LightningModal from 'lightning/modal';
import {api} from "lwc";

export default class PdpAddToCartModal extends LightningModal {
    @api headerLabel = 'Item was added to cart';

    handleGoToCart() {
        this.close('cart');
    }

    handleContinue() {
        this.close('continue');
    }
}