page 50155 PerfionDataSyncLog
{
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = PerfionDataSyncLog;
    caption = 'Data Sync Log';

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                ShowCaption = false;

                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                }
                field("Last Modified"; Rec."Last Modified")
                {
                    ApplicationArea = All;
                }
                field("Last Updated"; Rec."Last Updated")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
