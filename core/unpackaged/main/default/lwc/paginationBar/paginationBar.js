/* Copyright (c) 2021 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { LightningElement, api } from "lwc";

import {labels} from "./labels";
export default class PaginationBar extends LightningElement {
    @api pagination = {
        firstPage: 1,
        pageSize: 25,
        currentPage: 1,
        totalPages: 1,
        totalRecords: 0,
    };

    @api pageSizeOptions = [25, 50, 75];

    get hasRecords() {
        return this.pagination.totalRecords > 0;
    }

    firePaginationChangeEvent(payload) {
        this.dispatchEvent(
            new CustomEvent("paginationchange", {
                detail: payload,
            })
        );
    }

    previousHandler() {
        this.firePaginationChangeEvent({
            currentPage: this.pagination.currentPage - 1,
        });
    }

    nextHandler() {
        this.firePaginationChangeEvent({
            currentPage: this.pagination.currentPage + 1,
        });
    }

    setPage(event) {
        const currentPage = parseInt(event.target.dataset.page);
        this.firePaginationChangeEvent({
            currentPage,
        });
    }

    pageSizeChanged(event) {
        const pageSize = parseInt(event.target.value);
        this.firePaginationChangeEvent({
            pageSize,
            currentPage: 1,
        });
    }

    get sizeOptions() {
        return this.pageSizeOptions.map(size => ({
            size,
            isActive: size === this.pagination.pageSize,
        }));
    }

    get hasPrevious() {
        return this.pagination.currentPage > 1;
    }

    get hasNext() {
        return this.pagination.currentPage < this.pagination.totalPages;
    }

    get pages() {
        let current = this.pagination.currentPage,
            last = this.pagination.totalPages,
            delta = 1,
            left = current - delta,
            right = current + delta + 1,
            range = [],
            rangeWithDots = [],
            l;

        for (let i = 1; i <= last; i++) {
            if (i === 1 || i === last || (i >= left && i < right)) {
                range.push(i);
            }
        }
        for (let i of range) {
            if (l) {
                if (i - l === 2) {
                    rangeWithDots.push(l + 1);
                } else if (i - l !== 1) {
                    rangeWithDots.push("...");
                }
            }
            rangeWithDots.push(i);
            l = i;
        }
        return rangeWithDots.map((pageNumber, idx) => {
            if (pageNumber === "...") {
                return {
                    isDots: true,
                    id: `id-${idx}`,
                };
            } else {
                return {
                    number: pageNumber,
                    isActive: pageNumber === this.pagination.currentPage,
                    isDots: false,
                    id: `id-${idx}`,
                };
            }
        });
    }

    get labels() {
        return labels;
    }
}