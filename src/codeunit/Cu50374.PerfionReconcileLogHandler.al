codeunit 50374 PerfionReconcileLogHandler
{
    TableNo = PerfionDataReconcileLog;

    trigger OnRun()
    var

    begin
        Rec.Insert();
    end;

    procedure LogCatUpdate(catCode: Code[20]; updatedValue: Text; ogValue: Text; valueType: Enum PerfionValueType; changeType: Enum PerfionReconcileType)
    var
        perfionCatLog: Record PerfionDataReconcileLog;
    begin
        //PerfionItemLog.DeleteAll();
        Clear(perfionCatLog);
        perfionCatLog.Init();
        perfionCatLog.Code := catCode;
        perfionCatLog."Original Value" := updatedValue;
        perfionCatLog."Updated Value" := ogValue;
        perfionCatLog."Value Type" := valueType;
        perfionCatLog."Change Type" := changeType;
        perfionCatLog."Last Updated" := CurrentDateTime;
        StartSession(SessionId, Codeunit::PerfionReconcileLogHandler, CompanyName, perfionCatLog);
    end;

    var
        SessionID: Integer;
}
