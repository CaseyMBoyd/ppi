/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import {LightningElement, wire} from 'lwc';
import NewCartModal from "c/newCartModal";
import {MessageContext, publish} from "lightning/messageService";
import cartChanged from "@salesforce/messageChannel/lightning__commerce_cartChanged";
import basePath from "@salesforce/community/basePath";
import { effectiveAccount } from "commerce/effectiveAccountApi";


export default class CartSwitcherButtons extends LightningElement {
    @wire(MessageContext)
    messageContext;

    async openNewCartModal() {
        const success = await NewCartModal.open({
            size: "small",
            effectiveAccountId: effectiveAccount.accountId,
        });

        if(success) {
            publish(this.messageContext, cartChanged);

            setTimeout(() => {
                window.location.reload();
            }, 1000);
        }
    }

    manageCarts() {
        window.location = `${basePath}/manage-carts`;
    }
}