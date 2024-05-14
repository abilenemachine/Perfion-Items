codeunit 50364 PerfionLogHandler
{
    TableNo = PerfionLog;

    trigger OnRun()
    begin
        Rec.Insert();
    end;

    procedure enterLog(Process: Enum PerfionProcess; ProcessKey: Text[200]; ItemNo: Code[20]; ErrorMsg: Text[250])
    var
        perfionLog: Record PerfionLog;
    begin
        Clear(perfionLog);
        perfionLog.Init();
        perfionLog."Date/Time" := CurrentDateTime;
        perfionLog."Item No." := ItemNo;
        perfionLog.Process := Process;
        perfionLog."Key" := ProcessKey;
        perfionLog."Error Message" := ErrorMsg;
        StartSession(SessionID, Codeunit::PerfionLogHandler, CompanyName, perfionLog);
    end;

    var
        SessionID: Integer;
}
