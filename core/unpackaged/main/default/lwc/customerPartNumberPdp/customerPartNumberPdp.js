/* CRM-4420: Customer Part Number display on the Product Detail Page (Option A). */
import { LightningElement, api, wire } from "lwc";
import isFeatureEnabled from "@salesforce/apex/CustomerPartNumberController.isFeatureEnabled";
import getCustomerPartNumberForProduct from "@salesforce/apex/CustomerPartNumberController.getCustomerPartNumberForProduct";
import { getSessionContext } from "commerce/contextApi";

export default class CustomerPartNumberPdp extends LightningElement {
    @api recordId; // Product2 Id, provided by Experience Builder on the PDP

    accountId;
    isEnabled = false;
    customerPartNumber;

    async connectedCallback() {
        try {
            const sessionContext = await getSessionContext();
            this.accountId = sessionContext?.effectiveAccountId;
            if (!this.accountId || !this.recordId) {
                return;
            }
            this.isEnabled = await isFeatureEnabled({ accountId: this.accountId });
            if (!this.isEnabled) {
                return;
            }
            this.customerPartNumber = await getCustomerPartNumberForProduct({
                productId: this.recordId,
                accountId: this.accountId,
            });
        } catch (e) {
            // PDP renders normally if resolution fails.
            console.error("Customer PN (PDP) error:", e);
        }
    }

    get showComponent() {
        return this.isEnabled && !!this.customerPartNumber;
    }
}