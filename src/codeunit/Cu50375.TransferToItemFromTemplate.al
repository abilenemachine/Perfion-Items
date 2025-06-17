codeunit 50375 transferItemTemplToItem
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Templ. Mgt.", OnApplyTemplateOnBeforeItemModify, '', false, false)]
    local procedure "Item Templ. Mgt._OnApplyTemplateOnBeforeItemModify"(var Item: Record Item; ItemTempl: Record "Item Templ."; var IsHandled: Boolean; UpdateExistingValues: Boolean)
    begin
        Item.PerfionSync := ItemTempl.PerfionSync;
    end;
}