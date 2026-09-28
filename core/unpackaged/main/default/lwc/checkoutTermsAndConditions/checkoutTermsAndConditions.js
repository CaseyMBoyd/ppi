/* Copyright (c) 2023 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import {api, wire} from "lwc";
import {CheckoutInformationAdapter, CheckoutComponentBase} from "commerce/checkoutApi";
import {CheckoutStage} from "c/b2bUtils";

export default class CheckoutTermsAndConditions extends CheckoutComponentBase {
    _checkedByDefault;
    checked;
    showError = false;
    isLoading = false;

    baseUrl = window.location.href.substring(0,window.location.href.indexOf('checkout'));
    isSummary;


    @api privacyPolicyUrl;
    @api termsAndConditionsUrl;
    @api websitePolicyUrl;
    @api error;

    async connectedCallback() {
        await this.dispatchUpdateAsync({
            display: {
                complete: true,
            },
        });
        this.dispatchCommit();
    }

    async disconnectedCallback() {
        await this.dispatchUpdateAsync({
            display: {
                complete: false,
            },
        });
        this.dispatchCommit();
    }

    @api
    get checkedByDefault() {
        return this._checkedByDefault;
    }

    @api
    setAspect(newAspect) {
        this.isSummary = newAspect.summary;
    }

    set checkedByDefault(value) {
        this._checkedByDefault = value;
        this.checked = value;
    }

    handleChange(event) {
        this.checked = event.target.checked;
        this.showError = !this.checked;
    }

    @api
    get checkValidity() {
        this.showError = !this.checked;
        return this.checked;
    }

    get disableCheckbox() {
        return this.isSummary;
    }

    @api
    reportValidity() {
        this.showError = !this.checked;
        return this.checked;
    }

    @api
    async stageAction(checkoutStage) {
        switch (checkoutStage) {
            case CheckoutStage.REPORT_VALIDITY_SAVE:
                return this.reportValidity();
            case CheckoutStage.START_PAYMENT_SESSION:
                if(this.reportValidity()) {
                    await this.dispatchFinalizeAsync();
                    return true;
                }
                return false;
            default:
                return true
        }
    }

    @api
    async checkoutSave() {
        if (!this.reportValidity()) {
            throw new Error("Terms and Conditions must be accepted first by clicking the checkbox");
        }
    }

    @wire(CheckoutInformationAdapter, {})
    checkoutInfo({error, data}) {
        this.isPreview = this.isInSitePreview();

        if (!this.isPreview) {
            this.isLoading = true;
            if (data) {
                this.checkoutId = data.checkoutId;
                if (data.checkoutStatus === 200) {
                    this.isLoading = false;
                }
            } else if (error) {
                console.log(error);
            }
        } else {
            this.isLoading = false;
        }
    }

    isInSitePreview() {
        let url = document.URL;

        return (
            url.indexOf("sitepreview") > 0 ||
            url.indexOf("livepreview") > 0 ||
            url.indexOf("live-preview") > 0 ||
            url.indexOf("live.") > 0 ||
            url.indexOf(".builder.") > 0
        );
    }

    get privacyLink() {
        return this.baseUrl + this.privacyPolicyUrl;
    }

    get termsAndConditionLink() {
        return this.baseUrl + this.termsAndConditionsUrl;
    }

    get websitePrivacyLink() {
        return this.baseUrl + this.websitePolicyUrl;
    }

}