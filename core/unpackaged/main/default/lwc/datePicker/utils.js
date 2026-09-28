/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

/**
 * Converts date to string in YYYY-MM-DD format. It can be used instead of Date's toISOString()
 * as it does not take into account users TimeZone.
 * @param {Date} date Date to be converted to string
 * @returns String representing date in YYYY-MM-DD format
 */
export const dateToIsoString = (/** @type {Date} */ date) => {
    const yearStr = "" + date.getFullYear();
    const monthStr = ("" + (date.getMonth() + 1)).padStart(2, "0");
    const dayStr = ("" + date.getDate()).padStart(2, "0");
    return `${yearStr}-${monthStr}-${dayStr}`;
};