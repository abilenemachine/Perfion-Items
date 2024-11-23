codeunit 50369 PerfionDataInLogHandler
{
    TableNo = PerfionDataSyncInLog;

    trigger OnRun()
    var

    begin
        Rec.Insert();
    end;

    procedure LogItemUpdate(itemNo: Code[20]; updatedValue: Text; ogValue: Text; valueType: Enum PerfionValueType; lastModified: DateTime)
    var
        perfionItemLog: Record PerfionDataSyncInLog;
    begin
        //PerfionItemLog.DeleteAll();
        Clear(perfionItemLog);
        perfionItemLog.Init();
        perfionItemLog."Item No." := CopyStr(itemNo, 1, MaxStrLen(perfionItemLog."Item No."));
        perfionItemLog."Original Value" := CopyStr(ogValue, 1, MaxStrLen(perfionItemLog."Original Value"));
        perfionItemLog."Updated Value" := CopyStr(updatedValue, 1, MaxStrLen(perfionItemLog."Updated Value"));
        perfionItemLog."Value Type" := valueType;
        perfionItemLog."Last Modified" := lastModified;
        perfionItemLog."Last Updated" := CurrentDateTime;
        StartSession(SessionId, Codeunit::PerfionDataInLogHandler, CompanyName, perfionItemLog);
    end;

    procedure logMagentoSync(itemNo: Code[20]; isSyncd: Text)
    var
        perfionItemLog: Record PerfionDataSyncInLog;

    begin
        perfionItemLog.Reset();
        perfionItemLog.SetFilter("Item No.", itemNo);
        perfionItemLog.SetRange("Value Type", Enum::PerfionValueType::CoreValue);

        if perfionItemLog.FindLast() then begin
            perfionItemLog."Magento Sync" := isSyncd;
            perfionItemLog.Modify();
        end;

        perfionItemLog.Reset();
        perfionItemLog.SetFilter("Item No.", itemNo);
        perfionItemLog.SetRange("Value Type", Enum::PerfionValueType::CoreResource);

        if perfionItemLog.FindLast() then begin
            perfionItemLog."Magento Sync" := isSyncd;
            perfionItemLog.Modify();
        end;
    end;


    var
        SessionID: Integer;
}
