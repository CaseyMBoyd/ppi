import { LightningElement, wire } from 'lwc';
import { gql, graphql } from 'lightning/uiGraphQLApi';

export default class XStudio_QuickLinks extends LightningElement {
    @wire(graphql, {
        query: gql`
          query QuickLinks {
            uiapi {
              query {
                Quick_Link__mdt(orderBy: { Order__c: { order: ASC }}) {
                  edges {
                    node {
                        MasterLabel {
                            value
                        }
                        URL__c {
                            value
                        }
                        Icon__c {
                            value
                        }
                        Order__c {
                            value
                        }
                    }
                  }
                }
              }
            }
          }`,
      })
      quickLinksWire;

      get quickLinks() {
        console.log(this.quickLinksWire.data);
        return this.quickLinksWire.data ? this.quickLinksWire.data.uiapi.query.Quick_Link__mdt.edges : [];
      }
}