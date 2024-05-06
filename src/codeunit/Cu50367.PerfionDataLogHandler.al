codeunit 50367 PerfionDataLogHandler
{
    TableNo = PerfionDataSyncLog;

    trigger OnRun()
    var
        ItemNo: Code[20];
        ogPrice: Decimal;
        updatedPrice: Decimal;
        priceGroup: Code[20];
        lastModified: DateTime;

    begin
        ItemNo := Rec."Item No.";
        lastModified := Rec."Last Modified";
        Rec.Reset();
        if Rec.Get(ItemNo) then begin
            Rec."Last Updated" := CurrentDateTime;
            Rec.Modify();
        end
        else begin
            Rec.Reset();
            Rec.Init();
            Rec."Item No." := ItemNo;
            Rec."Last Modified" := lastModified;
            Rec."Last Updated" := CurrentDateTime;
            Rec.Insert();
        end;
    end;

    procedure LogItemUpdate(itemNo: Code[20]; lastModified: DateTime)
    var
        PerfionItemLog: Record PerfionDataSyncLog;
    begin
        //PerfionItemLog.DeleteAll();
        Clear(PerfionItemLog);
        PerfionItemLog.Init();
        PerfionItemLog."Item No." := ItemNo;
        PerfionItemLog."Last Modified" := lastModified;
        StartSession(SessionID, Codeunit::PerfionDataLogHandler, CompanyName, PerfionItemLog);
    end;

    var
        SessionID: Integer;
}
