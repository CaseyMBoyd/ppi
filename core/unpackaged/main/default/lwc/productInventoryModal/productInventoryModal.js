/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import {api} from 'lwc';
import LightningModal from 'lightning/modal';

export default class ProductInventoryModal extends LightningModal {
    @api recordId;
    @api title = 'Product Inventory Check';

    handleClose() {
        this.close();
    }
}