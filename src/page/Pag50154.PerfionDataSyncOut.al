page 50154 PerfionDataSyncOut
{
    PageType = CardPart;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = PerfionDataSyncOut;
    Caption = 'Data Sync Out';

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
            field(Processed; Rec.Processed)
            {
                Caption = 'Processed Last Run';
                ApplicationArea = All;
                ToolTip = 'How many prices were processed last run';
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
