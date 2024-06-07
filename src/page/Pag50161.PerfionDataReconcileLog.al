page 50161 PerfionDataReconcileLog
{
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = PerfionDataReconcileLog;
    SourceTableView = sorting("Last Updated") order(descending);
    caption = 'Perfion Reconcile Log';

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                ShowCaption = false;

                field("Item No."; Rec.Code)
                {
                    ApplicationArea = All;
                }
                field("Original Desc"; Rec."Original Value")
                {
                    ApplicationArea = All;
                }
                field("Updated Desc"; Rec."Updated Value")
                {
                    ApplicationArea = All;
                }
                field("Value Type"; Rec."Value Type")
                {
                    ApplicationArea = All;
                }
                field("Change Type"; Rec."Change Type")
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
