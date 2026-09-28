/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

const CheckoutStage = {
    CHECK_VALIDITY_UPDATE: 'CHECK_VALIDITY_UPDATE',
    REPORT_VALIDITY_SAVE: 'REPORT_VALIDITY_SAVE',
    BEFORE_PAYMENT: 'BEFORE_PAYMENT',
    PAYMENT: 'PAYMENT',
    START_PAYMENT_SESSION: 'START_PAYMENT_SESSION',
    BEFORE_PLACE_ORDER: 'BEFORE_PLACE_ORDER',
    PLACE_ORDER: 'PLACE_ORDER'
};

const isInSitePreview = () => {
    let url = document.URL;

    return (
        url.indexOf("sitepreview") > 0 ||
        url.indexOf("livepreview") > 0 ||
        url.indexOf("live-preview") > 0 ||
        url.indexOf("live.") > 0 ||
        url.indexOf(".builder.") > 0
    );
}

export {CheckoutStage, isInSitePreview}