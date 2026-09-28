({
    init : function(component, event, helper) {
        // Find the component whose aura:id is "flowData"
        var flow = component.find("flowData");
        // In that component, start your flow. Reference the flow's API Name.
        flow.startFlow("Opportunity_New_Opportunity");
    }
})