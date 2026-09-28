/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import LightningModal from 'lightning/modal';
import { api } from "lwc";

export default class BushingsModal extends LightningModal {
    @api headerLabel = 'Select a Bushing';
    @api bushings = [];

    handleAddToCart() {
        this.close('add');
    }

    handleCancel() {
        this.close('cancel');
    }
}