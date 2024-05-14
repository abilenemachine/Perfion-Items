page 50159 MagentoLog
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = MagentoLog;

    layout
    {
        area(Content)
        {
            repeater(Errors)
            {
                field("Date/Time"; Rec."Date/Time")
                {
                    ApplicationArea = All;
                }
                field("Processing Stage"; Rec.Process)
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
                field("Item No"; Rec."Item No")
                {
                    ApplicationArea = All;
                }

            }
        }
    }
}
