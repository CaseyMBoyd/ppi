/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { LightningElement, track } from 'lwc';
import getCurrentUsersAccount from '@salesforce/apex/AccountController.getCurrentUsersAccount';
export default class CurrentEffectiveAccount extends LightningElement {
    @track account = {};

    get accountName() {
        return this.account?.Name;
    }

    async connectedCallback() {
        this.account = await getCurrentUsersAccount();
    }
}