codeunit 50371 MagentoLogHandler
{
    TableNo = MagentoLog;

    var
        SessionId: Integer;

    trigger OnRun()
    begin
        Rec.Insert();
    end;

    procedure enterLog(Process: Enum MagentoProcess; ProcessKey: Text[200]; ErrorMsg: Text; itemNo: Code[20])
    var
        magentoLog: Record MagentoLog;
    begin
        Clear(magentoLog);
        magentoLog.Init();
        magentoLog."Date/Time" := CurrentDateTime;
        magentoLog.Process := Process;
        magentoLog."Key" := ProcessKey;
        magentoLog."Error Message" := ErrorMsg;
        magentoLog."Item No" := itemNo;
        StartSession(SessionId, Codeunit::MagentoLogHandler, CompanyName, magentoLog);
    end;
}
