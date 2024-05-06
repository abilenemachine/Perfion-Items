codeunit 50364 PerfionErrorHandler
{
    TableNo = PerfionErrorLog;

    trigger OnRun()
    begin
        Rec.Insert();
    end;

    procedure logPerfionError(Process: Text[50]; ErrorMsg: Text[250])
    var
        PerfionErrorLog: Record PerfionErrorLog;
    begin
        PerfionErrorLog.Init();
        PerfionErrorLog."Date/Time" := CurrentDateTime;
        //PerfionErrorLog."Item No." := ItemNo;
        PerfionErrorLog.Process := Process;
        PerfionErrorLog."Error Message" := ErrorMsg;
        StartSession(SessionID, Codeunit::PerfionErrorHandler, CompanyName, PerfionErrorLog);
    end;

    var
        SessionID: Integer;
}
