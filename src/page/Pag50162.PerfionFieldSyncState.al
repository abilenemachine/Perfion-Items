page 50162 "Perfion Field Sync State List"
{
    PageType = List;
    ApplicationArea = All;
    SourceTable = "Perfion Field Sync State";
    Caption = 'Perfion Field Sync State';
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Item number.';
                }
                field("Notes Last Outbound At"; Rec."Notes Last Outbound At")
                {
                    ApplicationArea = All;
                    ToolTip = 'When User Notes were last sent to Perfion.';
                }
                field("Notes Awaiting Ack"; Rec."Notes Awaiting Ack")
                {
                    ApplicationArea = All;
                    ToolTip = 'Waiting for Perfion to process User Notes.';
                }
                field("Notes Last Outbound Hash"; Rec."Notes Last Outbound Hash")
                {
                    ApplicationArea = All;
                    ToolTip = 'Hash of the last User Notes value sent.';
                }
                field("Notes Last Inbound At"; Rec."Notes Last Inbound At")
                {
                    ApplicationArea = All;
                    ToolTip = 'When User Notes were last received from Perfion.';
                }
                field("Apps Last Outbound At"; Rec."Apps Last Outbound At")
                {
                    ApplicationArea = All;
                    ToolTip = 'When Applications were last sent to Perfion.';
                }
                field("Apps Awaiting Ack"; Rec."Apps Awaiting Ack")
                {
                    ApplicationArea = All;
                    ToolTip = 'Waiting for Perfion to process Applications.';
                }
                field("Apps Last Outbound Hash"; Rec."Apps Last Outbound Hash")
                {
                    ApplicationArea = All;
                    ToolTip = 'Hash of the last Applications value sent.';
                }
                field("Apps Last Inbound At"; Rec."Apps Last Inbound At")
                {
                    ApplicationArea = All;
                    ToolTip = 'When Applications were last received from Perfion.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenItem)
            {
                ApplicationArea = All;
                Caption = 'Open Item';
                Image = Item;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Open the Item Card for this row.';
                trigger OnAction()
                var
                    Item: Record Item;
                begin
                    if Item.Get(Rec."Item No.") then
                        Page.Run(Page::"Item Card", Item);
                end;
            }

            action(ResetAwaitingAckNotes)
            {
                ApplicationArea = All;
                Caption = 'Reset Awaiting (Notes)';
                Image = ResetStatus;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Clear the awaiting-ack flag for User Notes.';
                trigger OnAction()
                begin
                    Rec.Validate("Notes Awaiting Ack", false);
                    Rec.Modify();
                end;
            }

            action(ResetAwaitingAckApps)
            {
                ApplicationArea = All;
                Caption = 'Reset Awaiting (Apps)';
                Image = ResetStatus;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Clear the awaiting-ack flag for Applications.';
                trigger OnAction()
                begin
                    Rec.Validate("Apps Awaiting Ack", false);
                    Rec.Modify();
                end;
            }
        }
    }
}