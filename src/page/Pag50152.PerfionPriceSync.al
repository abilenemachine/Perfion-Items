page 50152 PerfionPriceSync
{
    PageType = CardPart;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = PerfionPriceSync;
    Caption = 'Price Sync Info';

    layout
    {
        area(Content)
        {
            field(LastSync; Rec.LastSync)
            {
                Caption = 'Last Sync';
                ToolTip = 'Date and time of last sync';
                ApplicationArea = All;
                Width = 30;
            }
            field(TotalCount; Rec.TotalCount)
            {
                Caption = 'Total Count from API';
                ApplicationArea = All;
                ToolTip = 'How many items were found in last run';
            }
            field(Processed; Rec.Processed)
            {
                Caption = 'Processed Last Run';
                ApplicationArea = All;
                ToolTip = 'How many prices were processed last run';
                Width = 30;
            }
            field(SalesPriceList; Rec.SalesPriceList)
            {
                Caption = 'Sales Price List';
                ApplicationArea = All;
                TableRelation = "Price List Header".Code where("Price Type" = const("Price Type"::Sale));
                ToolTip = 'Select which price list to update';
                Width = 30;
            }
        }
    }
    trigger OnOpenPage()
    begin
        if Rec.IsEmpty then begin
            Rec.Init();
            Rec.Insert();
        end;
    end;
}
