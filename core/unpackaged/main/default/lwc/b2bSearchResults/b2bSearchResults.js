/* Copyright (c) 2021 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */
import { LightningElement, api, track, wire } from "lwc";

import labels from "./labels.js";
import { auraExceptionHandler } from "c/auraExceptionHandler";

import catalogSearch from "@salesforce/apex/SearchResultsControllerB2B.catalogProductSearch";
import fetchSortRules from "@salesforce/apex/SearchResultsControllerB2B.fetchSortRules";
import translateToProductSku from "@salesforce/apex/CustomerPartNumberController.translateToProductSku";
import {getSessionContext, AppContextAdapter} from "commerce/contextApi";

import {isInSitePreview} from "c/b2bUtils";
import {CurrentPageReference, NavigationMixin} from "lightning/navigation";

import ToastContainer from "lightning/toastContainer";


/**
* @slot Content-Region
* @slot Filters-Region
* @slot Sort-Region
* @slot No-Results-Region
*/
export default class SearchResultsB2B extends NavigationMixin(LightningElement) {

	showSpinner;
	pageSizeOptions = [10, 20, 50, 75]

	@track pageRef;

	@wire(CurrentPageReference)
	onPageReferenceChange(pageRef) {
		this.searchFilters.sortRuleId = pageRef.state?.sortRule;
		this.searchFilters.categoryId = pageRef.state?.category ?? pageRef.attributes?.recordId ?? this.recordId;
		this.searchFilters.refinements = pageRef.state?.refinements ? JSON.parse(decodeURIComponent(pageRef.state.refinements)) : [];

		this._pagination.pageSize = pageRef.state?.pageSize ? parseInt(pageRef.state.pageSize, 10) : this._pagination.pageSize;
		this._pagination.currentPage = pageRef.state?.page ? parseInt(pageRef.state.page, 10) : 1;

		this.pageRef = pageRef;

		this.term = pageRef.state?.term ?? '';

		(async () => {
			await this.searchProducts();
		})();
	}

	webStoreId;
	@wire(AppContextAdapter)
	wiredAppContext({ data, error }) {
		if (data) {
			this.webStoreId = data.webstoreId;
		} else if (error) {
			console.error('AppContextAdapter Error:', error);
		}
	}

	afterInitialSearch = false;

	searchFilters = {
		sortRuleId: null,
		categoryId: null,
		refinements: [],
	}

	sortRules;
	sessionContext;

	@api get recordId(){
		return this._categoryId;
	}
	set recordId(value) {
		this._categoryId = value;

		if(this.afterInitialSearch) {
			(async () => {
				// await this.searchProducts();
			})();
		}
	}
	_categoryId = null;

	@api searchPayload;

	get searchResults() {
		return this.searchPayload?.Results?.cardCollection;
	}

	@track _pageRef = {};
	@track products = [];
	@track searchQuery = "";


	get noResultsFound() {
		return (!this.showSpinner && this.products.length === 0) || isInSitePreview();
	}

	@api get term() {
		return this.searchQuery;
	}
	set term(value) {
		this.searchQuery = value;
	}


	get showPaginationBar() {
		return this._pagination.totalRecords > this._pagination.pageSize;
	}

	_pagination = {
		firstPage: 1,
		pageSize: 20,
		currentPage: 1,
		totalPages: 1,
		totalRecords: 0,
	};


	@api
	get pagination() {
		return this._pagination;
	}

	get paginationInfoString() {
		const total = this.pagination.totalRecords;

		if(this.term) {
			return `${total} Results for "${this.term}"`;
		}

		let start = this.pagination.pageSize * (this.pagination.currentPage - 1);
		const end = Math.min(start + this.pagination.pageSize, total);

		return this.products.length ? `${start + 1} - ${end} of ${total} products` : '0 Results';
	}

	constructor() {
		super();
		this.addEventListener('facetvaluetoggle', e => {
			const splitRefinement = e.detail.facetId.split(':');
			const refinement = splitRefinement[0];
			const attributeType = splitRefinement[1];
			const value = e.detail.id;
			const checked = e.detail.checked;
			if(this.searchFilters.refinements.find(r => r.nameOrId === refinement) != undefined) {
				const index = this.searchFilters.refinements.findIndex(r => r.nameOrId === refinement);
				const values = this.searchFilters.refinements[index].values;
				if(checked) {
					values.push(value);
				} else {
					values.splice(values.indexOf(value), 1);
				}
			} else {
				this.searchFilters.refinements.push({
					attributeType: attributeType,
					nameOrId: refinement,
					type: "DistinctValue",
					values: [value]
				})
			}
			(async () => {
				await this.searchProducts();
			})();
		});
	}
	async connectedCallback() {
		const toastContainer = ToastContainer.instance();
		toastContainer.maxToasts = 5;
		toastContainer.toastPosition = "top-center";
		navigation.addEventListener("navigate", e => {
			let triggerSearch = false;
			const destination = new URL(e.destination.url);
			if(destination.searchParams.has("sortRule")) {
				if(this.searchFilters.sortRuleId != destination.searchParams.get("sortRule")) {
					this.searchFilters.sortRuleId = destination.searchParams.get("sortRule");
					triggerSearch = true;
				}
			}
			// if(destination.searchParams.has("refinements")) {
			//     if(this.searchFilters.refinements != JSON.parse(decodeURIComponent(destination.searchParams.get("refinements")))) {
			//         this.searchFilters.refinements = JSON.parse(decodeURIComponent(destination.searchParams.get("refinements")));
			//         console.log('refinementsChange', this.searchFilters.refinements, JSON.parse(decodeURIComponent(destination.searchParams.get("refinements"))));
			//         triggerSearch = true;
			//     }
			// } else {
			//     if(this.searchFilters.refinements.length > 0) {
			//         this.searchFilters.refinements = [];
			//         console.log('refinementsChange', this.searchFilters.refinements, []);
			//         triggerSearch = true;
			//     }
			// }
			if(destination.searchParams.has("page")) {
				if(this._pagination.currentPage != parseInt(destination.searchParams.get("page"), 10)) {
					this._pagination.currentPage = parseInt(destination.searchParams.get("page"), 10);
					triggerSearch = true;
				}
			} else {
				if(this._pagination.currentPage != 1){
					this._pagination.currentPage = 1;
					triggerSearch = true;
				}
			}
			if(destination.searchParams.has("pageSize")) {
				if(this._pagination.pageSize != parseInt(destination.searchParams.get("pageSize"), 10)) {
					this._pagination.pageSize = parseInt(destination.searchParams.get("pageSize"), 10);
					triggerSearch = true;
				}
			} else {
				this._pagination.pageSize = this._pagination.pageSize;
			}

			if(triggerSearch) {
				(async () => {
					await this.searchProducts();
				})();
			}
		});
	}

	async getSessionContext() {
		if(!this.sessionContext){
			this.sessionContext = await getSessionContext();
		}

		return this.sessionContext;
	}

	async getSortRules() {
		if(!this.sortRules) {
			this.sortRules = await fetchSortRules();
		}

		return this.sortRules;
	}

	async searchProducts() {
		this.showSpinner = true;
		this.products = [];
		try {
			this.scrollTop();

			const categoryFilters = !this.searchFilters.categoryId || this.searchFilters.categoryId === 'ROOT_CATEGORY_ID'
				? []
				: [this.searchFilters.categoryId];

			const currentSortRuleId = this.searchFilters.sortRuleId;

			const [sortRules, sessionContext]
				= await Promise.all([this.getSortRules(),  this.getSessionContext()]);

			// CRM-4420: translate a Customer Part Number into the PPI SKU before searching.
			// Non-blocking: any failure falls back to the original term.
			let effectiveSearchTerm = this.term;
			if (effectiveSearchTerm) {
				try {
					const translatedSku = await translateToProductSku({
						customerPartNumber: effectiveSearchTerm,
						accountId: sessionContext.effectiveAccountId,
					});
					if (translatedSku) {
						effectiveSearchTerm = translatedSku;
					}
				} catch (error) {
					auraExceptionHandler.logAuraException(error);
				}
			}

			let sortRule = currentSortRuleId
				? sortRules.find(rule => rule.sortRuleId === currentSortRuleId)
				: sortRules[0];


			const searchFacets = (this.searchFilters.refinements || []).map(
				refinement => ({...refinement, facetType: refinement.type})
			)

			const searchInput = {
				sortRule,
				categoryFilters,
				searchFacets,
				pagination: this._pagination,
				searchQuery: effectiveSearchTerm,
				effectiveAccountId: sessionContext.effectiveAccountId,
			};
			const searchResult = await catalogSearch({input: searchInput});

			this.products = [...searchResult.products];
			this._pagination = {...searchResult.pagination};
		} catch (error) {
			auraExceptionHandler.logAuraException(error);
		} finally {
			this.showSpinner = false;
		}
	}

	async handlePaginationChange(event) {
		const paginationDiff = event.detail;

		this.pageRef = {
			...this.pageRef,
			state: {
				...this.pageRef.state,
				page: paginationDiff.currentPage ?? this._pagination.currentPage,
				pageSize: paginationDiff.pageSize ?? this._pagination.pageSize,
				refinements: encodeURIComponent(JSON.stringify(this.searchFilters.refinements)),
				sortRule: this.searchFilters.sortRuleId,
			}
		}

		this._pagination.currentPage = paginationDiff.currentPage;
		this._pagination.pageSize = paginationDiff.pageSize;
		await this.searchProducts();
		// this[NavigationMixin.Navigate](this.pageRef);
	}
	
	scrollTop() {
		try {
			this.template.querySelector(".topmost-div").scrollIntoView({
				behavior: "smooth",
				block: "center",
				inline: "nearest",
			});
		}
		catch(err) {}
	}

	get labels() {
		return labels;
	}
}