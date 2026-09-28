/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { LightningElement, wire, api } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import {getFieldValue, getRecord} from "lightning/uiRecordApi";

import userId from "@salesforce/user/Id";
import basePath from "@salesforce/community/basePath";

import TERRITORY_EMAIL from "@salesforce/schema/User.Contact.Account.Territory_Email__c";
import TERRITORY_NAME from "@salesforce/schema/User.Contact.Account.Territory_Text__c";

export default class OrderConfirmation extends LightningElement {
    @api headerText;
    @api bodyText;
    @api confirmationNumberText;
    @api salesmanText;
    @api continueShoppingButtonText;
    @api displayConfirmationNumber;

    @wire(CurrentPageReference)
    pageRef;

    @wire(getRecord, { recordId: userId, fields: [TERRITORY_EMAIL, TERRITORY_NAME] })
    wiredUser;

    get orderNumber() {
        return this.pageRef.state.orderNumber;
    }

    get territoryEmail() {
        return getFieldValue(this.wiredUser?.data, TERRITORY_EMAIL);
    }

    get territoryName() {
        return getFieldValue(this.wiredUser?.data, TERRITORY_NAME);
    }

    get formattedTerritoryText() {
        const contactText = `${this.territoryName} at ${this.territoryEmail}`;
        return (this.salesmanText || "{0}").replace('{0}', contactText);
    }

    get basePath() {
        return basePath;
    }
}