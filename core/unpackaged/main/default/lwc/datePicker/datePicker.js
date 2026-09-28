/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */
import { api, track, LightningElement } from "lwc";

import { dateToIsoString } from "./utils.js";
import { labels } from "./labels.js";
import locale from "@salesforce/i18n/locale";

const timezoneOffset = new Date().getTimezoneOffset() * 60 * 1000
const today = new Date();
const months = {
    0: labels.monthJanuary,
    1: labels.monthFebruary,
    2: labels.monthMarch,
    3: labels.monthApril,
    4: labels.monthMay,
    5: labels.monthJune,
    6: labels.monthJuly,
    7: labels.monthAugust,
    8: labels.monthSeptember,
    9: labels.monthOctober,
    10: labels.monthNovember,
    11: labels.monthDecember,
};

export default class CcDatePicker extends LightningElement {
    /**
     * A function that takes a date in YYYY-mm-DD format as a parameter and must return a
     * boolean value indicating whether date is selectable or not.
     * @callback ShowBeforeDay
     * @param {string} date date string in YYYY-mm-DD format
     * @returns {boolean} true if date is selectable
     */

    /**
     * @global
     * Text label for the input.
     */
    @api label;
    /**
     * @global
     * The minimum acceptable value for date input in YYYY-mm-DD format.
     */
    @api minDate;
    @api maxDate;

    @api disabled;
    @api required;

    /**
     * @global
     * Text that is displayed when the field is empty, to prompt the user for a valid entry.
     */
    @api placeholder;
    /**
     * @global
     * @type {ShowBeforeDay}
     */
    @api showBeforeDay;
    /**
     * @global
     * @readonly
     * Represents the validity states that an element can be in, with respect to constraint validation.
     * @type {boolean}
     */
    @api validity;

    /**
     * Specifies the value of an input element.
     * @type {string}
     */
    @api get value() {
        return this.selectedDate;
    }

    @api reset() {
        this.selectedDate = null;
        this.dateInput.value = null;
    }

    /**
     * @global
     * Displays the error messages and returns false if the input is invalid.
     * If the input is valid, reportValidity() clears displayed error messages and returns true.
     * @function reportValidity
     * @returns {boolean} true if input value is valid
     */
    @api reportValidity() {
        if(!this.required) {
            this.validity = true;
            return true;
        }

        let isInRange =
            this.minDate && this.selectedDate
                ? new Date(this.minDate).valueOf() <=
                  new Date(this.selectedDate).valueOf()
                : !this.required;

        isInRange =
            this.maxDate && this.selectedDate
                ? isInRange &&
                  new Date(this.maxDate).valueOf() >=
                      new Date(this.selectedDate).valueOf()
                : isInRange;

        const isShowBeforeDayCompliant =
            this.showBeforeDay && this.selectedDate
                ? this.showBeforeDay(this.selectedDate)
                : true;
        this.validity = isInRange && isShowBeforeDayCompliant;
        return this.validity;
    }

    @track weeks = [];
    @track years = [];

    globalOnClickHandler;
    currentYear = today.getFullYear();
    selectedDate;
    selectedMonth = today.getMonth();
    showDatepicker = false;

    get dateInput() {
        return this.template.querySelector(".slds-input");
    }

    get dropdownClass() {
        const classes = [
            "slds-form-element",
            "slds-dropdown-trigger",
            "slds-dropdown-trigger_click",
            "slds-size_1-of-1",
        ];

        if (!this.validity) {
            classes.push("slds-has-error");
        }

        if (this.showDatepicker) {
            classes.push("slds-is-open");
        }

        return classes.join(" ");
    }

    get errorMessage() {
        return this.selectedDate
            ? this.labels.errorMessage.replace("{0}", this.selectedDate)
            : 'You must enter a date.'
    }

    get labels() {
        return labels;
    }

    get month() {
        return months[this.selectedMonth];
    }

    get weekdays() {
        return [
            {
                short: this.labels.weekdayShortSun,
                long: this.labels.weekdaySunday,
            },
            {
                short: this.labels.weekdayShortMon,
                long: this.labels.weekdayMonday,
            },
            {
                short: this.labels.weekdayShortTue,
                long: this.labels.weekdayTuesday,
            },
            {
                short: this.labels.weekdayShortWed,
                long: this.labels.weekdayWednesday,
            },
            {
                short: this.labels.weekdayShortThu,
                long: this.labels.weekdayThursday,
            },
            {
                short: this.labels.weekdayShortFri,
                long: this.labels.weekdayFriday,
            },
            {
                short: this.labels.weekdayShortSat,
                long: this.labels.weekdaySaturday,
            },
        ];
    }

    get weeksCount() {
        const firstOfMonth = new Date(this.currentYear, this.selectedMonth, 1);
        const lastOfMonth = new Date(
            this.currentYear,
            this.selectedMonth + 1,
            0
        );

        const used = firstOfMonth.getDay() + lastOfMonth.getDate();

        return Math.ceil(used / 7);
    }

    get yearDropdown() {
        return this.template.querySelector("select");
    }

    connectedCallback() {
        document.addEventListener(
            "click",
            (this.globalOnClickHandler = this.handleLostFocus.bind(this))
        );
        this.reportValidity();
        this.generateYearOptions();
        this.refresh();
    }

    disconnectedCallback() {
        document.removeEventListener("click", this.globalOnClickHandler);
    }

    generateYearOptions() {
        for (let i = this.currentYear; i < this.currentYear + 20; i++) {
            this.years.push(i);
        }
    }

    getClassListForDate(date) {
        let classes = [];

        const minDateAsDate = new Date(this.minDate).valueOf();
        const maxDateAsDate = new Date(this.maxDate).valueOf();

        let isDisabled = false;
        if (
            (this.showBeforeDay &&
                !this.showBeforeDay(dateToIsoString(date))) ||
            minDateAsDate > date ||
            maxDateAsDate < date
        ) {
            classes.push("slds-disabled-text");
            isDisabled = true;
        }

        if (!isDisabled && date.getMonth() !== this.selectedMonth) {
            classes.push("slds-day_adjacent-month");
            classes.push("cc-is-disabled");
        }

        if (dateToIsoString(date) === dateToIsoString(today)) {
            classes.push("slds-is-today");
        }

        if (this.selectedDate === dateToIsoString(date)) {
            classes.push("slds-is-selected");
        }

        return classes.join(" ");
    }

    goToToday() {
        this.currentYear = today.getFullYear();
        this.yearDropdown.value = this.currentYear;
        this.selectedMonth = today.getMonth();
        this.refresh();
    }

    nextMonth() {
        if (this.selectedMonth < 11) {
            this.selectedMonth++;
        } else if (
            this.selectedMonth === 11 &&
            this.currentYear < this.years[this.years.length - 1]
        ) {
            this.selectedMonth = 0;
            this.currentYear++;
            this.yearDropdown.value = this.currentYear;
        }
        this.refresh();
    }

    previousMonth() {
        if (this.selectedMonth > 0) {
            this.selectedMonth--;
        } else if (
            this.selectedMonth === 0 &&
            this.currentYear > this.years[0]
        ) {
            this.selectedMonth = 11;
            this.currentYear--;
            this.yearDropdown.value = this.currentYear;
        }
        this.refresh();
    }

    refresh() {
        let startDay = new Date(
            this.currentYear,
            this.selectedMonth,
            1,
            0,
            0,
            0
        );

        if (startDay.getDay() !== 0) {
            startDay.setDate(startDay.getDate() - startDay.getDay());
        }

        this.weeks = [];

        for (let w = 1; w <= this.weeksCount; w++) {
            const week = Array(7).fill(0);
            for (let i = 0; i < 7; i++) {
                let classList = this.getClassListForDate(startDay);
                week[startDay.getDay()] = {
                    classList,
                    date: dateToIsoString(startDay),
                    monthDay: startDay.getDate(),
                    disabled: classList.includes("slds-disabled-text"),
                };
                startDay.setDate(startDay.getDate() + 1);
            }
            this.weeks.push({
                week,
                monthWeek: w,
            });
        }
    }

    handleDatepickerClick(event) {
        event.stopPropagation();
    }

    handleDatepickerFocus() {
        this.showDatepicker = true;
        this.refresh();
    }

    handleDatepickerInput(event) {
        this.selectedDate =
            event.target.value === "" ? null : event.target.value;
        this.showDatepicker = false;
        this.reportValidity();
        this.dispatchDateChangeEvent();
    }

    handleDateSelect(event) {
        if (event.target.dataset.disabled === "false") {
            this.selectedDate = event.target.dataset.date;

            const dateUTC = new Date(new Date(this.selectedDate).valueOf() + timezoneOffset);

            this.dateInput.value = new Intl.DateTimeFormat(locale).format(dateUTC)
            this.showDatepicker = false;
            this.reportValidity();
            this.dispatchDateChangeEvent();
        }
    }

    dispatchDateChangeEvent() {
        this.dispatchEvent(
            new CustomEvent("change", {
                detail: { value: this.selectedDate },
            })
        );
    }

    handleLostFocus() {
        this.showDatepicker = false;
    }

    handleYearChange(event) {
        this.currentYear = event.target.value;
        this.refresh();
    }

    preventTyping(event) {
        event.preventDefault();
    }
}