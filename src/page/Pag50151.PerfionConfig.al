page 50151 PerfionConfig
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = PerfionConfig;
    Caption = 'Perfion Integration';
    PromotedActionCategories = 'New,Process,Report,Manage,New Document,Request Approval,Customer,Page';

    layout
    {
        area(Content)
        {
            group("Connection Details")
            {
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                }
                field("Perfion Base URL"; Rec."Perfion Base URL")
                {
                    ApplicationArea = All;
                }
                field("Access Token"; Rec."Access Token")
                {
                    ApplicationArea = All;
                }

            }

            group("Price Sync In")
            {


                part(PerfionPriceSync; PerfionPriceSync)
                {
                    ApplicationArea = All;
                }

            }

            group("Price Sync In Log")
            {

                part(PriceSyncLog; PerfionPriceSyncLog)
                {
                    ApplicationArea = All;
                }

            }



            group("Data Sync Out")
            {
                part(PerfionDataSync; PerfionDataSync)
                {
                    ApplicationArea = All;
                }



            }

            group("Data Sync In Log")
            {

                part(DataSyncLog; PerfionDataSyncLog)
                {
                    ApplicationArea = All;
                }

            }
        }
    }

    actions
    {

        area(Navigation)
        {

            action("PriceSync")
            {
                ApplicationArea = All;
                Caption = 'Run Price Sync';
                Image = Cost;
                Promoted = true;

                trigger OnAction()
                var
                    perfionPriceSync: Codeunit PerfionPriceSync;
                begin
                    perfionPriceSync.Run();
                    CurrPage.Update();
                end;

            }

            action("DataSync")
            {
                ApplicationArea = All;
                Caption = 'Run Data Sync';
                Image = Cost;
                Promoted = true;

                trigger OnAction()
                var
                    perfionDataSync: Codeunit PerfionDataSync;
                begin
                    perfionDataSync.Run();
                    CurrPage.Update();
                end;

            }

            action("Errors")
            {
                ApplicationArea = All;
                Caption = 'Errors';
                Image = ErrorLog;
                Promoted = true;
                RunObject = Page PerfionErrorLog;

            }

            action("ClearPriceLog")
            {
                ApplicationArea = All;
                Caption = 'Clear Price Sync Log';
                Image = ClearLog;
                Promoted = true;

                trigger OnAction()
                var
                    perfionLog: Record PerfionPriceSyncLog;

                begin
                    perfionLog.DeleteAll();
                    CurrPage.Update();
                end;

            }

            action("ClearDataLog")
            {
                ApplicationArea = All;
                Caption = 'Clear Data Sync Log';
                Image = ClearLog;
                Promoted = true;

                trigger OnAction()
                var
                    perfionLog: Record PerfionDataSyncLog;

                begin
                    perfionLog.DeleteAll();
                    CurrPage.Update();
                end;

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
