codeunit 50367 PerfionDataLogHandler
{
    TableNo = PerfionDataSyncOutLog;

    trigger OnRun()
    var
        ItemNo: Code[20];
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

    procedure logItemUpdate(itemNo: Code[20]; lastModified: DateTime)
    var
        PerfionItemLog: Record PerfionDataSyncOutLog;
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
