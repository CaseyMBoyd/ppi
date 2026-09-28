/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { api, wire, track } from "lwc";
import {
    updateDeliveryMethod,
    notifyAndPollCheckout,
    CheckoutComponentBase,
    CheckoutInformationAdapter,
    CheckoutAddressAdapter,
} from "commerce/checkoutApi";
import { CheckoutStage } from "c/b2bUtils";
import { getFieldValue, getRecord } from "lightning/uiRecordApi";
// CRM-4423: CartItemsAdapter added to existing commerce/cartApi import (no duplicate import)
import { CartSummaryAdapter, CartItemsAdapter } from "commerce/cartApi";
import updateShippingInformation from "@salesforce/apex/CheckoutController.updateShippingInformation";
import saveSplitShipmentApproval from "@salesforce/apex/CheckoutController.saveSplitShipmentApproval";
import getOrderDeliveryMethods from "@salesforce/apex/CheckoutController.getOrderDeliveryMethods";
import fetchShippingCarriers from "@salesforce/apex/CheckoutController.fetchShippingCarriers";
import canFulfillOrder from "@salesforce/apex/XaCalloutController.canFulfillOrder";

import FIELD_CART_THIRD_PARTY_STATE from "@salesforce/schema/WebCart.Third_Party_Billing_StateCode__c";
import FIELD_CART_THIRD_STREET from "@salesforce/schema/WebCart.Third_Party_Billing_Street1__c";
import FIELD_CART_THIRD_CITY from "@salesforce/schema/WebCart.Third_Party_Billing_City__c";
import FIELD_CART_THIRD_COMPANY from "@salesforce/schema/WebCart.Third_Party_Billing_Company__c";
import FIELD_CART_THIRD_POSTAL_CODE from "@salesforce/schema/WebCart.Third_Party_Billing_Postal_Code__c";
import FIELD_CART_THIRD_STREET_TWO from "@salesforce/schema/WebCart.Third_Party_Billing_Street2__c";
import FIELD_CART_ALLOW_SPLIT_SHIPMENT from "@salesforce/schema/WebCart.Allow_Split_Shipment__c";

const METHOD_PPI_SELECTS = 'PPI Selects';
const METHOD_THIRD_PARTY_BILLING_ADDRESS = "3rd Party Bill To Address";
const METHOD_COLLECT = "Collect";
const METHOD_WILL_ADVISE = "Will Advise";

// CRM-4423: per-item weight threshold (lbs). Restriction triggers above this value.
const HEAVY_ITEM_WEIGHT_THRESHOLD = 140;

import ToastContainer from "lightning/toastContainer";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import USER_OBJECT from "@salesforce/schema/User";

export default class ShippingMethod extends CheckoutComponentBase {
    @track checkoutContext;
    @track cart;
    @track thirdPartyAddress = {};
    logisticsInformation;

    defaultRecordTypeId;
    enforceCarrierAccountNumber = false;

    selectedCarrier;
    selectedAccountNumber;
    initialLoad = true;

    // CRM-4423: holds cart items (with product Weight__c) from CartItemsAdapter
    cartItemsData = [];

    @wire(getObjectInfo, { objectApiName: USER_OBJECT })
    Function({ error, data }) {
        if (data) {
            this.defaultRecordTypeId = data.defaultRecordTypeId;
        } else if (error) {
            console.error("failed to fetch record type", error);
        }
    }

    @wire(getOrderDeliveryMethods) wiredOrderDeliveryMethods;

    get orderDeliveryMethods() {
        return (this.wiredOrderDeliveryMethods.data || []).map(method => ({
            id: method.Id,
            helpText: method?.Help_Text__c,
            name: method?.Name
        }));
    }

    @wire(fetchShippingCarriers)
    wiredCarriers;

    // CRM-4423: cart items wire. Platform-cached (already used by checkoutProductWeightNotice),
    // so this does not generate a duplicate network call.
    @wire(CartItemsAdapter)
    cartItemsResult({ error, data }) {
        if (data) {
            this.cartItemsData = data.cartItems || [];
        } else if (error) {
            // Matches this component's existing logging convention (no auraExceptionHandler here)
            console.error("failed to fetch cart items", error);
        }
    }

    get carriers() {
        return (this.wiredCarriers.data || []).map(carrier => ({
            label: carrier.Label,
            value: carrier.Label,
            enforceAccountNumber: carrier.Enforce_Account_Number__c,
            // CRM-4423: disable + tooltip when restriction is active and carrier is flagged
            disabled: this.shouldRestrictCarrier && carrier.Restricted_For_Heavy_Items__c,
            disabledTooltip: (this.shouldRestrictCarrier && carrier.Restricted_For_Heavy_Items__c)
                ? 'Not available for shipments over 140 lbs per package. ' +
                  'Use Will Advise and note to ship in multiple packages if applicable.'
                : undefined,
        }));
    }

    // ===== CRM-4423: carrier restriction logic =====

    // True if any INDIVIDUAL cart item has Weight__c > threshold (quantity NOT multiplied)
    get hasHeavyItem() {
        return (this.cartItemsData || []).some(item =>
            parseFloat(item.cartItem?.productDetails?.fields?.Weight__c || 0) * (parseInt(item.cartItem?.quantity, 10) || 0) > HEAVY_ITEM_WEIGHT_THRESHOLD
        );
    }

    // True if the selected delivery method triggers carrier restriction
    get isRestrictedDeliveryMethod() {
        const method = this.checkedMethod;
        return method?.name === METHOD_COLLECT ||
               method?.name === METHOD_THIRD_PARTY_BILLING_ADDRESS;
    }

    get cartTotalWeight() {
        return (this.cartItemsData || []).reduce((sum, item) => {
            const weight = parseFloat(item.cartItem?.productDetails?.fields?.Weight__c) || 0;
            const quantity = parseInt(item.cartItem?.quantity, 10) || 0;
            return sum + weight * quantity;
        }, 0);
    }

    get hasHeavyCartTotal() {
        return this.cartTotalWeight > HEAVY_ITEM_WEIGHT_THRESHOLD;
    }

    // Master flag: both conditions must be true simultaneously
    get shouldRestrictCarrier() {
        return (this.hasHeavyItem || this.hasHeavyCartTotal) && this.isRestrictedDeliveryMethod;
    }

    // Comma-separated list of restricted carrier labels, sourced dynamically from CMT
    get restrictedCarrierNames() {
        return (this.wiredCarriers.data || [])
            .filter(c => c.Restricted_For_Heavy_Items__c)
            .map(c => c.Label)
            .join(', ');
    }

    // Inline warning message using dynamic CMT carrier labels
    /*get heavyItemWarningMessage() {
        return `${this.restrictedCarrierNames} are not available for this order. ` +
               `If you would like your order to ship in multiple ` +
               `packages, please select Will Advise and note your request in Shipping Instructions.`;
    }*/

    // True if the currently selected carrier is one of the restricted carriers
    get isSelectedCarrierRestricted() {
        return (this.wiredCarriers.data || []).some(c =>
            c.Label === this.selectedCarrier && c.Restricted_For_Heavy_Items__c
        );
    }

    // ===== end CRM-4423 getters =====

    handleCarrierChange(event) {
        this.selectedCarrier = event.detail.value;

        const carrier = this.carriers.find(
            (carrier) => carrier.value === this.selectedCarrier
        );

        this.enforceCarrierAccountNumber = carrier?.enforceAccountNumber;
    }

    handleAccountNumberChange(event) {
        this.selectedAccountNumber = event.detail.value;
    }

    @wire(CheckoutAddressAdapter, {addressType: "Shipping"})
    onAddressFetch({error, data}){
        if(data && this.isAddressBlank(this.thirdPartyAddress)) {
            const defaultShipping = (data.items || []).find(address => address.isDefault) || (data.items || [])[0];

            if (defaultShipping) {
                this.thirdPartyAddress = {
                    company: defaultShipping.company,
                    city: defaultShipping.city,
                    state: defaultShipping.region,
                    street: defaultShipping.street,
                    street2: defaultShipping.street2,
                    postalCode: defaultShipping.postalCode,
                };
            }
        }
        else if(error) {
            console.error("failed to fetch shipping address", error);
        }
    }

    get shouldRunFulfillmentCheck() {
        return parseInt(this.cartSummary?.data?.totalProductCount, 10) > 1;
    }

    @wire(CheckoutInformationAdapter)
    async onContextLoad({ data }) {
        if (data) {
            if(this.initialLoad && data.deliveryGroups.items?.[0]?.availableDeliveryMethods?.length > 0) {
                let context = this.shallowCopy(data);
                context.deliveryGroups.items[0].selectedDeliveryMethod =
                    context.deliveryGroups.items[0].availableDeliveryMethods.filter(item => item.name === METHOD_PPI_SELECTS)[0];
                this.checkoutContext = {...context};
                await updateDeliveryMethod(context.deliveryGroups.items[0].selectedDeliveryMethod.id);
                await notifyAndPollCheckout(context);
                this.initialLoad = false;
            } else {
                this.checkoutContext = data;
            }


            if (this.shouldRunFulfillmentCheck && this.fulfillmentCheckNotRun) {
                const deliveryAddress =
                    this.checkoutContext.deliveryGroups?.items?.[0]
                        ?.deliveryAddress;

                (async () => {
                    try {
                        this.canFulfillOrder = await canFulfillOrder({
                            checkoutId: this.checkoutContext.checkoutId,
                            shippingAddress: {
                                city: deliveryAddress?.city,
                                contact: `${deliveryAddress?.firstName || ""} ${
                                    deliveryAddress?.lastName || ""
                                }`,
                                state: deliveryAddress?.region,
                                street1: deliveryAddress?.street,
                                zip: deliveryAddress?.postalCode,
                            },
                        });
                    } catch (err) {
                        console.error("fulfillment check failed", err);
                        this.canFulfillOrder = true;
                    } finally {
                        this.fulfillmentCheckNotRun = false;
                    }
                })();
            }
        }
    }

    isAddressBlank(address) {
        return Object.values(address).every(
            (value) => !value || value.trim() === ""
        );
    }

    fulfillmentCheckNotRun = true;
    canFulfillOrder = true;

    isSummary = false;
    acceptSplitShipment = true;

    get acceptSplitShipmentButtonStyles() {
        return {
            yes: this.acceptSplitShipment
                ? "border: 4px solid var(--dxp-g-brand); background: rgba(255, 255, 255, 0.3)"
                : "background: rgba(255, 255, 255, 0.3)",
            no: !this.acceptSplitShipment
                ? "border: 4px solid darkred; background: rgba(255, 255, 255, 0.3)"
                : "background: rgba(255, 255, 255, 0.3)",
        };
    }

    async handleAcceptSplitShipmentChange(event) {
        const { accept } = event.currentTarget.dataset;
        this.acceptSplitShipment = accept === "yes";

        this.isLoading = true;

        try {
            await saveSplitShipmentApproval({
                cartId: this.cartId,
                isAllowed: this.acceptSplitShipment,
            });
        } catch (err) {
            console.error("unable to save split shipment preferences", err);
            this.dispatchEvent(
                new ShowToastEvent({
                    message: "Error",
                    title: "We were unable to set your selection. Please contact the site Administration.",
                    variant: "error",
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    @api
    async stageAction(checkoutStage) {
        switch (checkoutStage) {
            case CheckoutStage.REPORT_VALIDITY_SAVE:
                if (this.checkValidity()) {
                    this.isLoading = true;
                    try {
                        const address = this.checkedMethod.displayAddressInput
                            ? this.thirdPartyAddress
                            : null;

                        await updateShippingInformation({
                            cartId: this.cartId,
                            address,
                            carrier: this.selectedCarrier,
                            carrierAccountNumber: this.selectedAccountNumber,
                            logisticsInformation: this.logisticsInformation,
                        });

                        return true;
                    } catch (err) {
                        await this.dispatchUpdateErrorAsync({
                            groupId: "ShippingError",
                            type: "/commerce/errors/checkout-failure",
                            exception:
                                "Unable to save billing address instructions",
                        });
                        return false;
                    } finally {
                        this.isLoading = false;
                    }
                }
                return Promise.resolve(this.checkValidity());
            default:
                return Promise.resolve(true);
        }
    }

    @wire(getRecord, {
        recordId: "$cartId",
        fields: [
            FIELD_CART_THIRD_PARTY_STATE,
            FIELD_CART_THIRD_STREET,
            FIELD_CART_THIRD_COMPANY,
            FIELD_CART_THIRD_CITY,
            FIELD_CART_THIRD_POSTAL_CODE,
            FIELD_CART_THIRD_STREET_TWO,
            FIELD_CART_ALLOW_SPLIT_SHIPMENT,
        ],
    })
    onCartFetch(cart) {
        this.cart = cart;

        this.acceptSplitShipment = getFieldValue(
            this.cart?.data,
            FIELD_CART_ALLOW_SPLIT_SHIPMENT
        );

        const address = {
            company: getFieldValue(this.cart?.data, FIELD_CART_THIRD_COMPANY),
            city: getFieldValue(this.cart?.data, FIELD_CART_THIRD_CITY),
            state: getFieldValue(this.cart?.data, FIELD_CART_THIRD_PARTY_STATE),
            street: getFieldValue(this.cart?.data, FIELD_CART_THIRD_STREET),
            street2: getFieldValue(
                this.cart?.data,
                FIELD_CART_THIRD_STREET_TWO
            ),
            postalCode: getFieldValue(
                this.cart?.data,
                FIELD_CART_THIRD_POSTAL_CODE
            ),
        };

        if(!this.isAddressBlank(address)) {
            this.thirdPartyAddress = address;
        }
    }

    @wire(CartSummaryAdapter)
    cartSummary;

    isLoading;

    async connectedCallback() {
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = "top-center";

        await this.dispatchRequestAspect({
            summarizable: false,
            uneditable: false,
        });
    }

    get checkedMethod() {
        return this.deliveryMethods.find((method) => method.checked);
    }

    checkValidity() {
        const inputs = this.template.querySelectorAll("[data-validate-input], lightning-textarea");

        inputs.forEach(el => el.reportValidity());

        const inputsValid = Array.from(inputs).reduce(
            (valid, el) => valid && el.reportValidity(),
            true
        );

        // CRM-4423: block Place Order if a restricted carrier is selected under restriction conditions.
        // Returns false before any Apex call — no backend modification required.
        if (this.shouldRestrictCarrier && this.isSelectedCarrierRestricted) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Invalid Carrier Selection',
                message: 'The selected carrier is not available for this order. ' +
                         'Please select a different carrier or choose Will Advise.',
                variant: 'error'
            }));
            return false;
        }

        return this.checkedMethod && inputsValid;
    }

    @api
    setAspect(newAspect) {
        this.isSummary = newAspect.summary;
    }

    get checkoutId() {
        return this.checkoutContext?.checkoutId;
    }

    get cartId() {
        return this.cartSummary?.data?.cartId;
    }

    handleInputChange(event) {
        const fieldName = event.target.name;
        this.thirdPartyAddress[fieldName] = event.target.value;
    }

    get deliveryGroups() {
        return this.checkoutContext?.deliveryGroups?.items || [];
    }

    get deliveryMethods() {
        return Object.values(
            this.deliveryGroups.reduce((acc, group) => {
                (group.availableDeliveryMethods || []).forEach((method) => {
                    const checked = method.id === group.selectedDeliveryMethod?.id;
                    acc[method.id] = {
                        ...method,
                        checked,
                        displayAddressInput: checked &&
                            method.name === METHOD_THIRD_PARTY_BILLING_ADDRESS,
                        displayCarrierSelector: checked &&
                            (method.name === METHOD_COLLECT || method.name === METHOD_THIRD_PARTY_BILLING_ADDRESS),
                        addressInputDisabled:
                            this.isSummary ||
                            method.id !== group.selectedDeliveryMethod?.id,
                        displayLogisticsInformation: checked && 
                            method.name === METHOD_WILL_ADVISE,
                        helpText: this.orderDeliveryMethods.find(e=>e.name === method.name)?.helpText
                    };
                });

                return acc;
            }, {})
        ).sort((a, b) => {
            if (a.name === METHOD_PPI_SELECTS) {
                return -1;
            } else if (b.name === METHOD_PPI_SELECTS) {
                return 1;
            }

            if (a.name === METHOD_THIRD_PARTY_BILLING_ADDRESS) {
                return 1;
            } else if (b.name === METHOD_THIRD_PARTY_BILLING_ADDRESS) {
                return -1;
            }

            if (a.name < b.name) {
                return -1;
            } else if (a.name > b.name) {
                return 1;
            }
            return 0;
        }).map(e=> {
            if(e.name === METHOD_PPI_SELECTS) {
                e.name = 'PPI Selects (Best Way PPD/ADD)';
            }
            return e;
        });
    }

    async handleSelection(event) {
        const methodId = event.target.dataset.id;

        try {
            const context = await updateDeliveryMethod(methodId);
            await notifyAndPollCheckout(context);
        } catch (err) {
            console.error("failed to update delivery", err);
        }
    }

    handleLogisticsInformationChange(event) {
        this.logisticsInformation = event.target.value;
    }

    shallowCopy(obj) {
        return JSON.parse(JSON.stringify(obj));
    }
}