import { api } from 'lwc';
import { CheckoutStage } from "c/b2bUtils";
import {
    updateShippingAddress,
    CheckoutComponentBase,
} from "commerce/checkoutApi";

export default class ShippingInstructions extends CheckoutComponentBase {
    shippingInstructions = '';
    isSummary = false;

    handleChange(event) {
        this.shippingInstructions = event.target.value;
    }

    @api
    setAspect(newAspect) {
        this.isSummary = newAspect.summary;
    }

    @api
    async stageAction(checkoutStage) {
        switch (checkoutStage) {
            case CheckoutStage.REPORT_VALIDITY_SAVE:
                return await updateShippingAddress({
                    shippingInstructions: this.shippingInstructions,
                });
            default:
                return Promise.resolve(true);
        }
    }
}