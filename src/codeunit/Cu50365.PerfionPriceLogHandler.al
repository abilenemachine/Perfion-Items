codeunit 50365 PerfionPriceLogHandler
{
    TableNo = PerfionPriceSyncLog;

    trigger OnRun()

    begin
        Rec.Insert();
    end;


    procedure logItemUpdate(itemNo: Code[20]; ogPrice: Decimal; updatedPrice: Decimal; priceGroup: Code[20]; lastModified: Text[20])
    var
        PerfionItemLog: Record PerfionPriceSyncLog;
    begin
        //PerfionItemLog.DeleteAll();
        Clear(PerfionItemLog);
        PerfionItemLog.Init();
        PerfionItemLog."Item No." := ItemNo;
        PerfionItemLog."Original Price" := ogPrice;
        PerfionItemLog."Updated Price" := updatedPrice;
        PerfionItemLog."Price Group" := priceGroup;
        PerfionItemLog."Last Modified" := lastModified;
        PerfionItemLog."Last Updated" := CurrentDateTime;
        StartSession(SessionID, Codeunit::PerfionPriceLogHandler, CompanyName, PerfionItemLog);
    end;

    var
        SessionID: Integer;
}
