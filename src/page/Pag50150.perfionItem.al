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
                field(Condition; Rec."Gen. Prod. Posting Group") { }
                field(ItemCategoryCode; Rec."Item Category Code") { }

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
                /** Updated **/

                field(QuantityKs; Rec."Quantity KS") { }
                field(QuantitySc; Rec."Quantity SC") { }
                field(QuantitySd; Rec."Quantity SD") { }
                field(QuantityMt; Rec."Quantity MT") { }

                field(ExcessAmount; Rec."Excess Amount") { }

                field(Demand; Rec.Demand) { }

                field(NMFC; Rec.NMFC) { }
                field(FreightDensity; Rec."Freight Density") { }

                field(MinQty; Rec."Minimum Qty") { }
                field(Oversize; Rec.Oversize) { }

                field(VendorCore; Rec."Vendor Core") { }
                field(UserNotes; Rec.userNotes) { }
                field(Application; Rec.application) { }
                field(CountryOfOrigin; Rec.CountryOfOrigin) { }

            }
        }
    }
}
