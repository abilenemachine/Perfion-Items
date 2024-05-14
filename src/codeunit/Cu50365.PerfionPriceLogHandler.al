codeunit 50365 PerfionPriceLogHandler
{
    TableNo = PerfionPriceSyncLog;

    trigger OnRun()
    var
        ItemNo: Code[20];
        ogPrice: Decimal;
        updatedPrice: Decimal;
        priceGroup: Code[20];
        lastModified: Text[20];

    begin
        ItemNo := Rec."Item No.";
        ogPrice := Rec."Original Price";
        updatedPrice := Rec."Updated Price";
        priceGroup := Rec."Price Group";
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
            Rec."Original Price" := ogPrice;
            Rec."Updated Price" := updatedPrice;
            Rec."Price Group" := priceGroup;
            Rec."Last Modified" := lastModified;
            Rec."Last Updated" := CurrentDateTime;
            Rec.Insert();
        end;
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
        StartSession(SessionID, Codeunit::PerfionPriceLogHandler, CompanyName, PerfionItemLog);
    end;

    var
        SessionID: Integer;
}
