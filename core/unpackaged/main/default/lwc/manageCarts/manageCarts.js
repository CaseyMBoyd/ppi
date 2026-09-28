/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */
import { LightningElement, track, wire } from "lwc";
import { MessageContext, publish } from "lightning/messageService";
import { auraExceptionHandler } from "c/auraExceptionHandler";
import { effectiveAccount } from "commerce/effectiveAccountApi";

import getCarts from "@salesforce/apex/CartController.fetchCarts";
import makeCartPrimary from "@salesforce/apex/CartController.makeCartPrimary";
import deleteCart from "@salesforce/apex/CartController.deleteCart";
import deleteCarts from "@salesforce/apex/CartController.deleteCarts";
import updateCartNames from "@salesforce/apex/CartController.updateCartNames";
import cartChanged from "@salesforce/messageChannel/lightning__commerce_cartChanged";

import ToastContainer from "lightning/toastContainer";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CurrentPageReference } from "lightning/navigation";
import basePath from "@salesforce/community/basePath";
import currentUserId from "@salesforce/user/Id";

import NewCartModal from "c/newCartModal";
import RenameCartModal from "c/renameCartModal";

import { refreshCartSummary } from "commerce/cartApi";

export default class ManageCarts extends LightningElement {
    @wire(MessageContext)
    messageContext;

    @wire(CurrentPageReference)
    async setCurrentPageReference(currentPageReference) {
        this.currentPageReference = currentPageReference;

        if(this.connected) {
            await this.initializePrimaryCart();
        } else {
            this.refreshed = true;
        }
    }

    currentPageReference;
    connected = false;
    refreshed = false;

    @track carts = [];
    @track displayedCarts = [];
    @track selectedCarts = [];
    @track draftValues = [];
    @track cartOwners = [];
    @track currentOwnerFilter;

    isLoading = true;
    maxCarts;
    primaryCartId;

    columns = [
        {
            label: "Name",
            fieldName: "CartActivationLink",
            type: "url",
            typeAttributes: {
                label: {
                    fieldName: "Name",
                },
                value: {
                    fieldName: "Name",
                },
            },
            sortable: true,
        },
        { label: "Created Date", fieldName: "CreatedDate", type: "date" },
        {
            label: "Total Amount",
            fieldName: "GrandTotalAmount",
            type: "currency",
        },
        { label: "Active", fieldName: "Active", type: "boolean" },
        { label: "Owner", fieldName: "OwnerName", type: "text" },
        {
            type: "action",
            typeAttributes: {
                rowActions: [
                    { label: "Activate", name: "activate" },
                    { label: "Rename Cart", name: "rename"},
                    { label: "Delete", name: "delete" },
                ],
            },
        },
    ];

    get effectiveAccountId() {
        return effectiveAccount.accountId;
    }

    get cardTitle() {
        return `Carts (${this.carts.length.toString(10)})`;
    }

    get disableDelete() {
        return this.selectedCarts.length === 0 || this.carts.length === 1;
    }

    get showCartOwnerFilter() {
        return this.cartOwners?.length > 1;
    }

    get selectedFilter() {
        return !!this.currentOwnerFilter;
    }

    async connectedCallback() {
        this.connected = true;
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = "top-center";

        await this.getCarts();

        if(this.refreshed) {
            await this.initializePrimaryCart();
        }
    }

    async getCarts() {
        this.isLoading = true;

        try {
            const carts = await getCarts({effectiveAccountId: this.effectiveAccountId});
            if (carts.length) {
                this.maxCarts = carts.length && carts.length === 15;
                this.processCarts(carts);
            }
        }
        catch(err) {
            auraExceptionHandler.logAuraException(err);
        }
        finally {
            this.isLoading = false;
        }
    }

    processCarts(res) {
        let cartOwnerMap = {};
        this.carts = res.map((c) => {
            if(!c.IsSecondary) {
                this.primaryCartId = c.Id;
            }

            if(!cartOwnerMap[c.OwnerId]) {
                cartOwnerMap[c.OwnerId] = `${c.Owner.FirstName} ${c.Owner.LastName}`;
            }

            return {
                ...c,
                CartActivationLink: `${basePath}/manage-carts?c__activeCartId=${c.Id}`,
                Active: !c.IsSecondary && currentUserId === c.OwnerId,
                OwnerName: `${c.Owner.FirstName} ${c.Owner.LastName}`,
            }
        });

        this.displayedCarts = this.carts;

        this.cartOwners = Object.keys(cartOwnerMap).map((key) => {
            return {
                label: cartOwnerMap[key],
                value: key
            }
        });
    }

    async handleRowActions(event) {
        const { action, row } = event.detail;
        switch (action.name) {
            case "activate":
                await this.makeCartPrimary(row.Id);
                break;
            case "rename":
                await this.renameCart(row.Id);
                break;
            case "delete":
                await this.deleteCart(row.Id);
                break;
        }
    }

    handleSelection() {
        this.selectedCarts = this.template
            .querySelector("lightning-datatable")
            .getSelectedRows();
    }

    async makeCartPrimary(cartId) {
        if (this.cartIsActive(cartId)) {
            this.dispatchEvent(
                new ShowToastEvent({
                    message: "Warning",
                    title: `Selected cart is already active.`,
                    variant: "warning",
                })
            );
        } else {
            this.isLoading = true;

            try {
                await makeCartPrimary({ cartId });
                await refreshCartSummary();
                this.dispatchEvent(
                    new ShowToastEvent({
                        message: "Success",
                        title: `Cart was successfully activated.`,
                        variant: "success",
                    })
                );
                publish(this.messageContext, cartChanged);
                await this.getCarts();
            }
            catch(err) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        message: "Error",
                        title: `There was an error activating your cart, please try again later.`,
                        variant: "error",
                    })
                );
                auraExceptionHandler.logAuraException(err);
            }
            finally {
                this.isLoading = false;
            }
        }
    }

    cartIsActive(cartId) {
        const cart = this.carts.find((c) => c.Id === cartId)

        return cart.Active;
    }

    async deleteCart(cartId) {
        if (this.cartIsActive(cartId)) {
            this.dispatchEvent(
                new ShowToastEvent({
                    message: "Warning",
                    title: `You cannot remove an active cart.`,
                    variant: "warning",
                })
            );

            return;
        }

        this.isLoading = true;

        try {
            await deleteCart({ cartId })
            this.dispatchEvent(
                new ShowToastEvent({
                    message: "Success",
                    title: `Cart was successfully removed.`,
                    variant: "success",
                })
            );
            await this.getCarts();
        }
        catch(error) {

            this.dispatchEvent(
                new ShowToastEvent({
                    message: "Error",
                    title: `We were unable to remove the cart at this time, please try again later.`,
                    variant: "error",
                })
            );
            auraExceptionHandler.logAuraException(error);
        }
        finally {
            this.isLoading = false;
        }

    }

    async renameCart(cartId) {
        const cart = this.carts.find((c) => c.Id === cartId);

        const success = await RenameCartModal.open({
            size: "small",
            cartId: cartId,
            cartName: cart.Name
        });

        if(success) {
            console.log('success and completed');
            await this.getCarts();
            publish(this.messageContext, cartChanged);
        }
    }

    async deleteCarts() {
        if (this.selectedCarts.find((c) => !c.IsSecondary) != null) {
            this.dispatchEvent(
                new ShowToastEvent({
                    message: "Warning",
                    title: `You selected an active cart for removal, this cart will not be removed.`,
                    variant: "warning",
                })
            );
        }

        let cartIds = this.selectedCarts.reduce(
            (acc, c) => (c.IsSecondary ? acc.concat(c.Id) : acc),
            []
        );

        if (cartIds.length > 0) {
            this.isLoading = true;

            try {

                await deleteCarts({ cartIds });

                this.dispatchEvent(
                    new ShowToastEvent({
                        message: "Success",
                        title: `Carts were successfully removed`,
                        variant: "success",
                    })
                );
                await this.getCarts();
            }
            catch(error) {

                this.dispatchEvent(
                    new ShowToastEvent({
                        message: "Error",
                        title: `We were unable to remove the carts at this time, please try again later.`,
                        variant: "error",
                    })
                );
                auraExceptionHandler.logAuraException(error);
            }
            finally {
                this.isLoading = false;
            }
        }
    }

    async openNewCartModal() {
        const success = await NewCartModal.open({
            size: "small",
            effectiveAccountId: this.effectiveAccountId,
        });

        if(success) {
            publish(this.messageContext, cartChanged);
            await this.getCarts();
        }
    }

    async handleCartNameChange(event) {
        this.isLoading = true;

        try {
            await updateCartNames({carts: event.detail.draftValues});

            this.dispatchEvent(
                new ShowToastEvent({
                    message: "Success",
                    title: `Cart name was successfully updated.`,
                    variant: "success",
                })
            );

            await this.getCarts();
            this.draftValues = [];
        }
        catch(err) {
            this.dispatchEvent(
                new ShowToastEvent({
                    message: "Error",
                    title: `There was an error updating your cart name, please try again later.`,
                    variant: "error",
                })
            );
            auraExceptionHandler.logAuraException(err);
        }
        finally {
            this.isLoading = false;
        }
    }

    async initializePrimaryCart() {
        if (this.currentPageReference.state?.c__activeCartId && this.primaryCartId !== this.currentPageReference.state.c__activeCartId) {
            await this.makeCartPrimary(this.currentPageReference.state.c__activeCartId);
        }
    }

    handleFilterChange(event) {
        this.currentOwnerFilter = event.detail.value;
        this.displayedCarts = this.carts.filter((c) => c.OwnerId === this.currentOwnerFilter);
    }

    clearFilter() {
        this.currentOwnerFilter = null;
        this.displayedCarts = [...this.carts];
    }
}