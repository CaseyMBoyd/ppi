/* Copyright (c) 2023 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { api, LightningElement, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { publish, MessageContext, subscribe } from "lightning/messageService";
import { auraExceptionHandler } from "c/auraExceptionHandler";
import NewCartModal from "c/newCartModal";
import basePath from "@salesforce/community/basePath";
import { effectiveAccount } from "commerce/effectiveAccountApi";

import getCarts from "@salesforce/apex/CartController.fetchCarts";
import makeCartPrimary from "@salesforce/apex/CartController.makeCartPrimary";
import cartChanged from "@salesforce/messageChannel/lightning__commerce_cartChanged";

import ToastContainer from "lightning/toastContainer";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { labels } from "./labels.js";
import currentUserId from "@salesforce/user/Id";
import { refreshCartSummary } from "commerce/cartApi";


export default class CartSwitcher extends NavigationMixin(LightningElement) {
    @wire(MessageContext)
    messageContext;

    @api cartPage;
    @api recordId;

    @track cartOptions = [];
    @track carts = [];
    @track currentActiveCart = {};
    @track isError = false;
    @track selectedCart = {};

    cartChangedSubscription = null;
    isLoading = true;
    maxCarts;

    get effectiveAccountId() {
        return effectiveAccount.accountId;
    }

    subscribeToCartChangedEvent() {
        if (!this.cartChangedSubscription) {
            this.cartChangedSubscription = subscribe(
                this.messageContext,
                cartChanged,
                () => {
                    this.getCarts();
                }
            );
        }
    }

    connectedCallback() {
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = "top-center";

        this.subscribeToCartChangedEvent();
        this.getCarts();
    }

    getCarts() {
        this.isLoading = true;
        getCarts({effectiveAccountId: this.effectiveAccountId})
            .then((carts) => {
                this.prepareCartOptions(carts);
                this.setActiveCart(carts);
                this.carts = carts;
                this.isError = false;
                this.maxCarts = carts.length && carts.length === 15;
            })
            .catch((error) => {
                this.isError = true;
                auraExceptionHandler.logAuraException(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    prepareCartOptions(carts) {
        if (carts.length) {
            this.cartOptions = carts.map((cart) => ({
                value: cart.Id,
                label: cart.Name,
            }));
        } else {
            this.cartOptions = [{ label: this.labels.noCartsFound, value: "" }];
        }
    }

    setActiveCart(carts) {
        if (carts.length) {
            this.currentActiveCart = carts.find((cart) => !cart.IsSecondary && cart.OwnerId === currentUserId) || {};
            this.selectedCart = this.currentActiveCart;
        }
    }

    async makeCartPrimary(event) {
        this.selectedCart = this.carts.find((c) => c.Id === event.detail.value);
        this.isLoading = true;

        try {
            await makeCartPrimary({ cartId: this.selectedCart.Id })
            await refreshCartSummary();

            this.dispatchEvent(
              new ShowToastEvent({
                  message: "Success",
                  title: `Cart ${this.selectedCart.Name} selected.`,
                  variant: "success",
              })
            );
            publish(this.messageContext, cartChanged);
            window.location.reload();
        }
        catch(error) {
            auraExceptionHandler.logAuraException(error);
            this.dispatchEvent(
              new ShowToastEvent({
                  message: "Error",
                  title: `We were unable to switch to "${this.selectedCart.Name}" cart.`,
                  variant: "error",
              })
            );
        }
        finally {
            this.isLoading = false;
        }
    }

    get labels() {
        return labels;
    }

    async openNewCartModal() {
        const success = await NewCartModal.open({
            size: "small",
            effectiveAccountId: this.effectiveAccountId,
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