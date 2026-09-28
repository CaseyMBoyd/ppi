/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { LightningElement, api } from "lwc";

export default class QuantitySelector extends LightningElement {
    @api minQty = 1;
    @api maxQty = 10_000;
    @api get qty() {
        return this._qty;
    }

    set qty(value) {
        this._qty = parseInt(value, 10);
    }

    _qty = 1;

    get disableIncrement() {
        return this._qty >= this.maxQty;
    }

    get disableDecrement() {
        return this._qty <= this.minQty;
    }

    handleChange(event) {
        const { action } = event.target.dataset;
        let newQty;

        if (action === "increment") {
            newQty = this._qty + 1;
        } else if (action === "decrement") {
            newQty = this._qty - 1;
        } else {
            newQty = parseInt(event.target.value, 10);
        }

        this._qty = Math.max(this.minQty, Math.min(this.maxQty, newQty));

        this.dispatchEvent(
            new CustomEvent("change", { detail: { value: this._qty } })
        );
    }
}