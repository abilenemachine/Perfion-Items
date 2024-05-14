page 50158 PerfionDataSyncInLog
{
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = PerfionDataSyncInLog;
    SourceTableView = sorting("Last Updated") order(descending);
    caption = 'Perfion Data Sync In Log';

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
                field("Original Value"; Rec."Original Value")
                {
                    ApplicationArea = All;
                }
                field("Updated Value"; Rec."Updated Value")
                {
                    ApplicationArea = All;
                }
                field("Value Type"; Rec."Value Type")
                {
                    ApplicationArea = All;
                }
                field("Magento Sync"; Rec."Magento Sync")
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
