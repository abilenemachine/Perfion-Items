page 50156 PerfionErrorLog
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = PerfionErrorLog;
    SourceTableView = order(descending);
    AdditionalSearchTerms = 'Warehouse, Magento Warehouse';

    layout
    {
        area(Content)
        {
            repeater("Errors")
            {
                field("Date/Time"; Rec."Date/Time")
                {
                    ApplicationArea = All;
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                }
                field(Process; Rec.Process)
                {
                    ApplicationArea = All;
                }
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
