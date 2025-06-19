page 50153 PerfionPriceSyncLog
{
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = PerfionPriceSyncLog;
    SourceTableView = sorting("Last Updated") order(descending);
    caption = 'Price Sync Log';

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
                field("Original Price"; Rec."Original Price")
                {
                    ApplicationArea = All;
                }
                field("Updated Price"; Rec."Updated Price")
                {
                    ApplicationArea = All;
                }
                field("Price Group"; Rec."Price Group")
                {
                    ApplicationArea = All;
                }
                field("UOM"; Rec.UOM)
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
