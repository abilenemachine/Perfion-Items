page 50157 PerfionDataSyncIn
{
    PageType = CardPart;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = PerfionDataSyncIn;
    Caption = 'Data Sync In Info';

    layout
    {
        area(Content)
        {
            field(LastSync; Rec.LastSync)
            {
                Caption = 'Last Sync';
                ToolTip = 'Date and time of last sync';
                ApplicationArea = All;
            }
            field(TotalCount; Rec.TotalCount)
            {
                Caption = 'Total Count from API';
                ApplicationArea = All;
                ToolTip = 'How many items were found in last run';
            }
            field(Processed; Rec.Processed)
            {
                Caption = 'Changed Last Run';
                ApplicationArea = All;
                ToolTip = 'How many items were changed last run';
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
