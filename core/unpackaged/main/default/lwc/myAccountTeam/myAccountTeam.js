/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { LightningElement } from 'lwc';
import getCurrentUsersAccount from '@salesforce/apex/AccountController.getCurrentUsersAccount';

export default class MyAccountTeam extends LightningElement {
    accountTeamInfo = {};

    async connectedCallback() {
        try {
            this.accountTeamInfo = await getCurrentUsersAccount() || {};
        } catch (error) {
            console.error(error);
        }
    }
}