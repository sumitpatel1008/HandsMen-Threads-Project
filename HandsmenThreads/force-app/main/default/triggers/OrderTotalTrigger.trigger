trigger OrderTotalTrigger on HandsMen_Order__c (before insert, before update) {
    Set<Id> productIds = new Set<Id>();

    // Step 1: Collect product IDs from orders
    for (HandsMen_Order__c order : Trigger.new) {
        if (order.HandsMen_Product__c != null) {
            productIds.add(order.HandsMen_Product__c);
        }
    }

    // Step 2: Query the products and store them in a map
    Map<Id, HandsMen_Product__c> productMap = new Map<Id, HandsMen_Product__c>(
        [SELECT Id, Price__c FROM HandsMen_Product__c WHERE Id IN :productIds]
    );

    // Step 3: Calculate the total amount
    for (HandsMen_Order__c order : Trigger.new) {
        if (
            order.HandsMen_Product__c != null &&
            order.Quantity__c != null &&
            productMap.containsKey(order.HandsMen_Product__c)
        ) {
            HandsMen_Product__c product = productMap.get(order.HandsMen_Product__c);
            
            if (product.Price__c != null) {
                order.Total_Amount__c = order.Quantity__c * product.Price__c;
            } else {
                order.Total_Amount__c = 0; // fallback if price is null
            }
        }
    }
}