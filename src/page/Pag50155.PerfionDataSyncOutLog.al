page 50155 PerfionDataSyncOutLog
{
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = PerfionItems;
    SourceTableView = sorting("No.") order(ascending);
    caption = 'Perfion Data Sync Out Log';

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                ShowCaption = false;

                field("No."; Rec."No.") { }
                field("Reference No."; Rec."Reference No.") { }
                field(Description; Rec.Description) { }
                field(GTIN; Rec.GTIN) { }
                field("Replenishment System"; Rec."Replenishment System") { }
                field("Inventory Posting Group"; Rec."Inventory Posting Group") { }
                field("Gen. Prod. Posting Group"; Rec."Gen. Prod. Posting Group") { }
                field("Item Category Code"; Rec."Item Category Code") { }
                field("Drop Ship"; Rec."Drop Ship") { }
                field("Vendor No."; Rec."Vendor No.") { }
                field("Unit Cost"; Rec."Unit Cost") { }
                field("Vendor Cost"; Rec."Vendor Cost") { }
                field("Vendor Core"; Rec."Vendor Core") { }
                field("Vendor Date Changed"; Rec."Vendor Date Changed") { }
                field("Minimum Qty"; Rec."Minimum Qty") { }
                field(NMFC; Rec.NMFC) { }
                field(Oversize; Rec.Oversize) { }
                field("Freight Density"; Rec."Freight Density") { }
                field(Length; Rec.Length) { }
                field(Width; Rec.Width) { }
                field(Height; Rec.Height) { }
                field(Cubage; Rec.Cubage) { }
                field(Weight; Rec.Weight) { }
                field("Item Class Description"; Rec."Item Class Description") { }

                field(Demand; Rec.Demand) { }
                field("Excess Amount"; Rec."Excess Amount") { }

                field("Quantity KS"; Rec."Quantity KS") { }
                field("Quantity MT"; Rec."Quantity MT") { }
                field("Quantity SC"; Rec."Quantity SC") { }
                field("Quantity SD"; Rec."Quantity SD") { }
            }
        }
    }
}
