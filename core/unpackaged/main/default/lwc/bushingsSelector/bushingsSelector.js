/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { LightningElement, api } from 'lwc';

export default class BushingsSelector extends LightningElement {
    @api bushings = [];

    selectedBushing = null;

    connectedCallback() {
        this.selectedBushing = this.bushings.find(bushing => bushing.isDefault)?.value ?? null;
        this.dispatchEvent(new CustomEvent('bushingchange', {
            detail: {
                bushingId: this.selectedBushing
            }
        }));
    }

    get bushingsOptions() {
        let options = [
            { label: '- None -', value: null},
            ...this.bushings.map(item => ({
                ...item,
                label: `${item.bore} (${item.material})`,
            })),
        ]

        return options;
    }

    handleBushingChange(event) {
        this.selectedBushing = event.detail.value;

        this.dispatchEvent(new CustomEvent('bushingchange', {
            detail: {
                bushingId: this.selectedBushing
            },
            bubbles: true,
            composed: true,
        }));
    }
}