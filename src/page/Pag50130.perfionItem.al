page 50150 perfionItem
{
    APIGroup = 'AM';
    APIPublisher = 'Abilene';
    APIVersion = 'v1.06';
    Caption = 'perfionItem';
    EntityName = 'perfionItem';
    EntitySetName = 'perfionItem';
    PageType = API;
    Editable = false;
    SourceTable = PerfionItems;
    ODataKeyFields = SystemId;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field(id; Rec.SystemId) { }
                field(No; Rec."No.") { }
                field(Description; Rec.Description) { }
                field(GTIN; Rec.GTIN) { }
                field(Blocked; Rec.Blocked) { }
                field(InventoryPostingGroup; Rec."Inventory Posting Group") { }
                field(ItemCategoryCode; Rec."Item Category Code") { }
                field(LastDateTimeModified; Rec."Last DateTime Modified") { }
                field(DropShip; Rec."Drop Ship") { }
                field(Length; Rec.Length) { }
                field(Width; Rec.Width) { }
                field(Height; Rec.Height) { }
                field(Cubage; Rec.Cubage) { }
                field(Weight; Rec.Weight) { }
                field(ItemClass; Rec."Item Class Description") { }
                field(ReplenishmentSystem; Rec."Replenishment System") { }
                field(VendorNo; Rec."Vendor No.") { }
                field(UnitCost; Rec."Unit Cost") { }
                field(VendorCost; Rec."Vendor Cost") { }
                field(ReferenceNo; Rec."Reference No.") { }
                field(ProcurementDateChanged; Rec."Procurement Date Changed") { }
                field(QuantityKs; Rec."Quantity KS") { }
                field(QuantitySc; Rec."Quantity SC") { }
                field(QuantitySd; Rec."Quantity SD") { }
                field(QuantityMt; Rec."Quantity MT") { }

            }
        }
    }
}
