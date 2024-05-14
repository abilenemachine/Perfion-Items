page 50156 PerfionLog
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = PerfionLog;
    SourceTableView = order(descending);

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
                field("Key"; Rec."Key")
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
