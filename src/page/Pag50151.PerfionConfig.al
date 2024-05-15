page 50151 PerfionConfig
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = PerfionConfig;
    Caption = 'Perfion Integration';

    layout
    {
        area(Content)
        {

            group("Perfion Sync Info")
            {
                group(ConfigGroup)
                {
                    ShowCaption = false;

                    field("Manual Date"; Rec."Manual Date")
                    {

                    }
                }
            }

            group(PriceSyncGroup)
            {
                ShowCaption = true;
                Caption = 'Price Sync';

                part(PerfionPriceSync; PerfionPriceSync)
                {
                    ApplicationArea = All;
                }

                part(PriceSyncLog; PerfionPriceSyncLog)
                {
                    ApplicationArea = All;
                }
            }

            group(DataSyncInGroup)
            {
                ShowCaption = true;
                Caption = 'Data Sync In';
                part(PerfionDataSyncIn; PerfionDataSyncIn)
                {
                    ApplicationArea = All;
                }

                part(PerfionDataSyncInLog; PerfionDataSyncInLog)
                {
                    ApplicationArea = All;
                }
            }

            group(DataSyncOutGroup)
            {
                ShowCaption = true;
                Caption = 'Data Sync Out';
                part(PerfionDataSync; PerfionDataSyncOut)
                {
                    ApplicationArea = All;
                }
                part(DataSyncLog; PerfionDataSyncOutLog)
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

            action("DataSyncOut")
            {
                ApplicationArea = All;
                Caption = 'Run Data Sync Out';
                Image = ImportDatabase;
                Promoted = true;

                trigger OnAction()
                var
                    perfionDataSync: Codeunit PerfionDataSyncOut;
                begin
                    perfionDataSync.Run();
                    CurrPage.Update();
                end;

            }

            action("DataSyncIn")
            {
                ApplicationArea = All;
                Caption = 'Run Data Sync In';
                Image = ExportDatabase;
                Promoted = true;

                trigger OnAction()
                var
                    perfionDataSync: Codeunit PerfionDataSyncIn;
                begin
                    perfionDataSync.Run();
                    CurrPage.Update();
                end;

            }

            action("Perfion Errors")
            {
                ApplicationArea = All;
                Caption = 'Perfion Log';
                Image = ErrorLog;
                Promoted = true;
                RunObject = Page PerfionLog;

            }

            action("Magento Errors")
            {
                ApplicationArea = All;
                Caption = 'Magento Log';
                Image = ErrorLog;
                Promoted = true;
                RunObject = Page MagentoLog;

            }

            action("ClearPerifonLog")
            {
                ApplicationArea = All;
                Caption = 'Clear Perfion Log';
                Image = ClearLog;
                Promoted = true;

                trigger OnAction()
                var
                    perfionLog: Record PerfionLog;

                begin
                    perfionLog.DeleteAll();
                end;

            }

            action("ClearMagentoLog")
            {
                ApplicationArea = All;
                Caption = 'Clear Magento Log';
                Image = ClearLog;
                Promoted = true;

                trigger OnAction()
                var
                    magentoLog: Record MagentoLog;

                begin
                    magentoLog.DeleteAll();
                end;

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

            action("ClearDataOutLog")
            {
                ApplicationArea = All;
                Caption = 'Clear Data Sync Out Log';
                Image = ClearLog;
                Promoted = true;

                trigger OnAction()
                var
                    perfionLog: Record PerfionDataSyncOutLog;

                begin
                    perfionLog.DeleteAll();
                    CurrPage.Update();
                end;

            }

            action("ClearDataInLog")
            {
                ApplicationArea = All;
                Caption = 'Clear Data Sync In Log';
                Image = ClearLog;
                Promoted = true;

                trigger OnAction()
                var
                    perfionLog: Record PerfionDataSyncInLog;

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
