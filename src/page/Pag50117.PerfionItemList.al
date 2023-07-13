page 50117 PerfionItemList
{
    ApplicationArea = All;
    Caption = 'PerfionItemList';
    PageType = List;
    SourceTable = PerfionItems;
    SourceTableView = sorting(Id) order(descending);
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field(Id; Rec.Id)
                {
                    ToolTip = 'Specifies the value of the Id field.';

                }
                field("No."; Rec."No.")
                {
                    ToolTip = 'Specifies the value of the No. field.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies the value of the Description field.';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ToolTip = 'Specifies the value of the Vendor No. field.';
                }
                field("Vendor Date Changed"; Rec."Vendor Date Changed")
                {
                    ToolTip = 'Specifies the date vendor was changed on item procurement card';
                }
                field("Unit Cost"; Rec."Unit Cost")
                {
                    ToolTip = 'Specifies the value of the Unit Cost field.';
                }
                field("Vendor Cost"; Rec."Vendor Cost")
                {
                    ToolTip = 'Specifies the value of the Unit Cost field.';
                }
                field("Vendor Cost Date"; Rec."Vendor Cost Date")
                {
                    ToolTip = 'Specifies the starting date of the purchase price for vendor';
                }
                field("Reference No."; Rec."Reference No.")
                {
                    ToolTip = 'Specifies the value of the Reference No. field.';
                }
                field("Replenishment System"; Rec."Replenishment System") { }
                field("Gen. Prod. Posting Group"; Rec."Gen. Prod. Posting Group") { }
                field(Length; Rec.Length) { }
                field(Weight; Rec.Weight) { }
                field("Item Class Description"; Rec."Item Class Description") { }

                field("Quantity KS"; Rec."Quantity KS") { }
                field("Quantity SC"; Rec."Quantity SC") { }
                field("Quantity SD"; Rec."Quantity SD") { }
                field("Quantity MT"; Rec."Quantity MT") { }


            }
        }
    }
}
