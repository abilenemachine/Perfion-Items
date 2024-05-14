codeunit 50369 PerfionDataInLogHandler
{
    TableNo = PerfionDataSyncInLog;

    trigger OnRun()
    var

    begin

    end;

    procedure LogItemUpdate(itemNo: Code[20]; updatedValue: Text; ogValue: Text; valueType: Enum PerfionValueType; lastModified: DateTime)
    var
        perfionItemLog: Record PerfionDataSyncInLog;
    begin
        //PerfionItemLog.DeleteAll();
        Clear(perfionItemLog);
        perfionItemLog.Init();
        perfionItemLog."Item No." := ItemNo;
        perfionItemLog."Original Value" := ogValue;
        perfionItemLog."Updated Value" := updatedValue;
        perfionItemLog."Value Type" := valueType;
        perfionItemLog."Last Modified" := lastModified;
        perfionItemLog."Last Updated" := CurrentDateTime;
        perfionItemLog.Insert();
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
