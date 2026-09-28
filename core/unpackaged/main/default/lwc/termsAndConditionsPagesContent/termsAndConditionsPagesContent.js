/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { api, LightningElement, wire } from "lwc";
import { getContent } from "experience/cmsDeliveryApi";
import siteId from "@salesforce/site/Id";

export default class TermsAndConditionsPagesContent extends LightningElement {
    @api contentId;

    @wire(getContent, { channelOrSiteId: siteId, contentKeyOrId: "$contentId" })
    wiredContent;

    get content() {
        return this.wiredContent?.data?.contentBody?.richtextnode ?? "";
    }
}