trigger StockDeductionTrigger on HandsMen_Order__c (after insert, after update) {
    Set<Id> productIds = new Set<Id>();

    // Collect product IDs from new records where status is Confirmed
    for (HandsMen_Order__c order : Trigger.new) {
        if (order.Status__c == 'Confirmed' && order.HandsMen_Product__c != null) {
            productIds.add(order.HandsMen_Product__c);
        }
    }

    if (productIds.isEmpty()) return;

    // Query inventories for those products
    Map<Id, Inventory__c> inventoryMap = new Map<Id, Inventory__c>(
        [SELECT Id, Stock_Quantity__c, HandsMen_Product__c 
         FROM Inventory__c 
         WHERE HandsMen_Product__c IN :productIds]
    );

    List<Inventory__c> inventoriesToUpdate = new List<Inventory__c>();

    for (Integer i = 0; i < Trigger.new.size(); i++) {
        HandsMen_Order__c newOrder = Trigger.new[i];
        HandsMen_Order__c oldOrder = Trigger.isUpdate ? Trigger.old[i] : null;

        if (newOrder.Status__c == 'Confirmed' && newOrder.HandsMen_Product__c != null) {

            Inventory__c inv = null;

            for (Inventory__c temp : inventoryMap.values()) {
                if (temp.HandsMen_Product__c == newOrder.HandsMen_Product__c) {
                    inv = temp;
                    break;
                }
            }

            if (inv == null) continue;

            // Calculate how much quantity to deduct
            Decimal qtyToDeduct = newOrder.Quantity__c;

            // On update: only deduct the difference if product or quantity changed
            if (Trigger.isUpdate) {
                Boolean statusChangedToConfirmed = oldOrder.Status__c != 'Confirmed' && newOrder.Status__c == 'Confirmed';
                Boolean productChanged = oldOrder.HandsMen_Product__c != newOrder.HandsMen_Product__c;
                Boolean quantityChanged = oldOrder.Quantity__c != newOrder.Quantity__c;

                if (!statusChangedToConfirmed && !productChanged && !quantityChanged) {
                    continue; // no relevant change, skip
                }

                if (oldOrder.Status__c == 'Confirmed' && oldOrder.HandsMen_Product__c == newOrder.HandsMen_Product__c) {
                    // reverse the old quantity first (restock)
                    inv.Stock_Quantity__c += oldOrder.Quantity__c;
                }
            }

            // Now subtract new quantity
            if (inv.Stock_Quantity__c >= qtyToDeduct) {
                inv.Stock_Quantity__c -= qtyToDeduct;
                inventoriesToUpdate.add(inv);
            } else {
                newOrder.addError(
                    'Not enough stock available for the product "' + newOrder.HandsMen_Product__c + '". ' +
                    'Available: ' + inv.Stock_Quantity__c + ', Ordered: ' + qtyToDeduct
                );
            }
        }
    }

    if (!inventoriesToUpdate.isEmpty()) {
        update inventoriesToUpdate;
    }
}