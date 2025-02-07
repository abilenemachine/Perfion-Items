codeunit 50363 PerfionDataSyncOut
{
    trigger OnRun()
    var
        bcItems: Record Item;
        recPerfionItems: Record PerfionItems;
        Values: List of [Decimal];
        perfionDataSync: Record PerfionDataSyncOut;
        changeCount: Integer;
        ItemUOM: Record "Item Unit of Measure";
    //startTime, endTime : Time;
    //executionTime: Duration;

    begin
        perfionDataSync.LastSync := CreateDateTime(Today, Time);
        recPerfionItems.Reset();
        recPerfionItems.DeleteAll;

        bcItems.SetRange(Type, Enum::"Item Type"::Inventory);
        bcItems.SetRange("Add To Perfion", true);
        //bcItems.SetFilter("No.", 'AMAR26497-U');
        //bcItems.SetFilter("No.", '%1|%2|%3|%4|%5|%6|%7|%8|%9|%10|%11|%12|%13|%14|%15|%16|%17|%18|%19', 'AMX34112', 'AMJD40CABK-L', 'AMJD40UK-L', 'AMJDHK', 'AMJD40CPK', 'AMGLUE', 'AMAH158880', 'HC0935', 'AMX2710106', 'AMAH220019', 'AMAH218490', 'AMHXE36443', 'AMHXE36441', 'AMHXE36439', 'AMHXE80252', 'AMHXE80253', 'AMHXE80254', 'AMHXE36445', 'AMHXE80255');

        if bcItems.FindSet() then
            repeat
                //startTime := Time;
                recPerfionItems.Init();
                recPerfionItems."No." := bcItems."No.";
                recPerfionItems.Description := bcItems.Description;
                recPerfionItems.GTIN := bcItems.GTIN;
                recPerfionItems.Blocked := bcItems.Blocked;
                recPerfionItems."Replenishment System" := bcItems."Replenishment System";
                recPerfionItems."Gen. Prod. Posting Group" := getCondition(bcItems);
                recPerfionItems."Item Category Code" := bcItems."Item Category Code";
                recPerfionItems."Drop Ship" := bcItems."Drop Ship";
                recPerfionItems."Sales Unit of Measure" := bcItems."Sales Unit of Measure";
                recPerfionItems."Purch. Unit of Measure" := bcItems."Purch. Unit of Measure";

                ItemUOM.Reset();
                ItemUOM := getUom(bcItems."No.");
                recPerfionItems.Length := ItemUOM.Length;
                recPerfionItems.Width := ItemUOM.Width;
                recPerfionItems.Height := ItemUOM.Height;
                recPerfionItems.Weight := ItemUOM.Weight;
                recPerfionItems.Cubage := ItemUOM.Cubage;

                recPerfionItems.NMFC := bcItems."IWX LTL NMFC";
                recPerfionItems."Freight Density" := bcItems."IWX LTL Freight Density";
                recPerfionItems.Oversize := getOversize(bcItems);

                recPerfionItems."Item Class Description" := getItemClass(bcItems."No.");

                recPerfionItems."Vendor No." := getVendor(bcItems);

                recPerfionItems."Unit Cost" := bcItems."Unit Cost";

                Values := getPurchasePrice(bcItems);
                recPerfionItems."Vendor Cost" := Values.Get(1);
                recPerfionItems."Vendor Core" := Values.Get(2);

                recPerfionItems."Minimum Qty" := minQty;

                recPerfionItems."Excess Amount" := getExcessAmount(bcItems."No.");

                recPerfionItems."Reference No." := getItemRef(bcItems);

                recPerfionItems.application := bcItems.application;
                recPerfionItems.userNotes := bcItems.userNotes;

                recPerfionItems.Demand := EH.GetUsageLast12Months(bcItems."No.");

                recPerfionItems.CountryOfOrigin := getCountryOfOrigin(bcItems);

                bcItems.CalcFields("Assembly BOM");

                if bcItems."Assembly BOM" then begin
                    recPerfionItems."Quantity KS" := getBomComponents(bcItems."No.", 'KS');
                    recPerfionItems."Quantity SC" := getBomComponents(bcItems."No.", 'SC');
                    recPerfionItems."Quantity SD" := getBomComponents(bcItems."No.", 'SD');
                    recPerfionItems."Quantity MT" := getBomComponents(bcItems."No.", 'MT');
                end
                else begin
                    recPerfionItems."Quantity KS" := getQty(bcItems."No.", 'KS');
                    recPerfionItems."Quantity SC" := getQty(bcItems."No.", 'SC');
                    recPerfionItems."Quantity SD" := getQty(bcItems."No.", 'SD');
                    recPerfionItems."Quantity MT" := getQty(bcItems."No.", 'MT');
                end;

                recPerfionItems.Insert();
                logHandler.logItemUpdate(recPerfionItems."No.", bcItems."Last DateTime Modified");
                changeCount += 1;

            //endTime := Time;
            //executionTime := endTime - startTime;
            //logTiming.logTiming(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync Out", 'OnRun', bcItems."No.", '', startTime, endTime, executionTime);

            until bcItems.Next() = 0;

        perfionDataSync.Processed := changeCount;
        perfionDataSync.Modify();
    end;

    var
        procureVendor: Code[20];
        minQty: Decimal;

    local procedure getCountryOfOrigin(item: Record Item): Code[10]
    begin
        if item."Country/Region of Origin Code" = 'US' then
            exit('Made in USA')
        else
            exit('')
    end;

    local procedure getOversize(item: Record Item) booleanText: Decimal
    begin
        if item.Oversize then
            exit(1)
        else
            exit(0)
    end;

    local procedure getCondition(item: Record Item) itemVendor: text[20]
    begin
        case item."Gen. Prod. Posting Group" of
            'COMBINE', 'ENGINE USED', 'TRACTOR':
                itemVendor := 'USED';
            'ENGINE REBUILT', 'REBUILT', 'RECON', 'REBUILD':
                itemVendor := 'REMANUFACTURED';
            'FAB', 'NEW', 'NRMACHINE':
                itemVendor := 'NEW';
        end;
        exit(itemVendor);
    end;


    local procedure getBomComponents(itemNo: Code[20]; location: code[10]): Decimal
    var
        bComponent: Record "BOM Component";
        qty: Decimal;
        qtyInit: Decimal;
        qtyMin: Decimal;
        qtyPer: Decimal;
    begin

        qtyPer := 0;
        qty := 0;
        qtyMin := 0;
        qtyInit := 0;

        bComponent.Reset();
        bComponent.SetRange("Parent Item No.", itemNo);
        if bComponent.FindSet() then
            repeat
                if bComponent.Selection = Enum::Selection::Mandatory then begin
                    qty := getQty(bComponent."No.", location);
                    if qty >= bComponent."Quantity per" then begin
                        qtyPer := Round(qty / bComponent."Quantity per", 1, '<');
                        if qtyPer = 0 then
                            exit(0)
                        else
                            if qtyInit = 0 then begin
                                qtyMin := qtyPer;
                                qtyInit := 1;
                            end
                            else
                                if qtyPer < qtyMin then
                                    qtyMin := qtyPer
                                else
                                    qtyInit := 2;
                    end
                    else
                        exit(0);
                end;
            until bComponent.Next() = 0;
        //logTiming.logTiming(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync Out", 'getBomComponents', itemNo, '', startTime, endTime, executionTime);
        exit(qtyMin);

    end;

    procedure getQty(itemNo: Code[20]; location: code[10]): Decimal
    var
        item: Record Item;

        qtyOnSalesOrder: Decimal;
        qtyOnAssy: Decimal;
        qtyiLedger: Decimal;
        qtyUnsellableBin: Decimal;
        qtyFinal: Decimal;
        qtyProduction: Decimal;
        qtyTransfer: Decimal;

    begin
        qtyOnSalesOrder := 0;
        qtyUnsellableBin := 0;
        qtyOnAssy := 0;
        qtyiLedger := 0;
        qtyFinal := 0;
        qtyProduction := 0;
        qtyTransfer := 0;

        qtyTransfer := getTransferQty(itemNo, location);
        qtyProduction := getProductionQty(itemNo, location);
        qtyUnsellableBin := getUnsellableQty(itemNo, location);
        qtyiLedger := getLedgerQty(itemNo, location);
        qtyOnAssy := getAssemblyQty(itemNo, location);
        qtyOnSalesOrder := getSalesLineQty(itemNo, location);

        qtyFinal := qtyiLedger - (qtyOnSalesOrder + qtyOnAssy + qtyUnsellableBin + qtyTransfer + qtyProduction);

        if qtyFinal < 0 then
            qtyFinal := 0;

        exit(qtyFinal);
    end;

    procedure getTransferQty(itemNo: Code[20]; location: code[10]) value: Decimal
    var
        tLines: Record "Transfer Line";
    begin
        tLines.Reset();
        tLines.SetRange("Item No.", itemNo);
        tLines.SetRange("Transfer-from Code", location);
        tLines.SetFilter("Outstanding Qty. (Base)", '<>0');
        tLines.SetRange("Shipment Date", 0D, Today);
        if tLines.CalcSums("Outstanding Quantity") then
            value := tLines."Outstanding Quantity";
    end;

    procedure getProductionQty(itemNo: Code[20]; location: code[10]) value: Decimal
    var
        prodCompLines: Record "Prod. Order Component";
    begin
        prodCompLines.Reset();
        prodCompLines.SetRange("Item No.", itemNo);
        prodCompLines.SetRange("Location Code", location);
        prodCompLines.SetFilter(Status, '%1|%2', Enum::"Production Order Status"::"Firm Planned", Enum::"Production Order Status"::Released);
        prodCompLines.SetFilter("Remaining Qty. (Base)", '<>0');
        prodCompLines.SetRange("Due Date", 0D, Today);
        if prodCompLines.CalcSums("Remaining Quantity") then
            value := prodCompLines."Remaining Quantity";
    end;

    procedure getUnsellableQty(itemNo: Code[20]; location: code[10]) value: Decimal
    var
        wEntryBins: Record "Warehouse Entry";
        UnsellableBin: Record "Unsellable Bins";
        UnsellabelFilter1: Text;
        UnsellableFilter2: Text;
    begin
        if UnsellableBin.FindSet() then
            repeat
                UnsellabelFilter1 += UnsellableBin."Bin Code" + '|';
                UnsellableFilter2 += '<>' + UnsellableBin."Bin Code" + '&';
            until UnsellableBin.Next() = 0;
        UnsellabelFilter1 := UnsellabelFilter1.TrimEnd('|');
        UnsellableFilter2 := UnsellableFilter2.TrimEnd('&');

        wEntryBins.Reset();
        wEntryBins.SetRange("Item No.", itemNo);
        wEntryBins.SetRange("Location Code", location);
        wEntryBins.SetFilter("Bin Code", UnsellabelFilter1);
        if wEntryBins.CalcSums(Quantity) then
            value += wEntryBins.Quantity;

        wEntryBins.Reset();
        wEntryBins.SetRange("Item No.", itemNo);
        wEntryBins.SetRange("Location Code", location);
        wEntryBins.SetFilter("Bin Code", UnsellableFilter2);
        wEntryBins.SetFilter(Dedicated, 'True');
        if wEntryBins.CalcSums(Quantity) then
            value += wEntryBins.Quantity;
    end;

    procedure getLedgerQty(itemNo: Code[20]; location: code[10]) value: Decimal
    var
        iLedger: Record "Item Ledger Entry";
    begin
        iLedger.Reset();
        iLedger.SetRange("Item No.", itemNo);
        iLedger.SetRange("Location Code", location);
        if iLedger.CalcSums(Quantity) then
            value := iLedger.Quantity;
    end;

    procedure getAssemblyQty(itemNo: Code[20]; location: code[10]) value: Decimal
    var
        assyLines: Record "Assembly Line";
    begin
        assyLines.Reset();
        assyLines.SetRange("Document Type", Enum::"Assembly Document Type"::Order);
        assyLines.SetRange(Type, Enum::"BOM Component Type"::Item);
        assyLines.SetRange("Location Code", location);
        assyLines.SetRange("No.", itemNo);

        if assyLines.FindSet() then
            repeat
                value += assyLines."Remaining Quantity";
            until assyLines.Next() = 0;
    end;

    procedure getSalesLineQty(itemNo: Code[20]; location: code[10]) value: Decimal
    var
        sLines: Record "Sales Line";
    begin
        sLines.Reset();
        sLines.SetRange("Document Type", Enum::"Sales Document Type"::Order);
        sLines.SetRange("Drop Shipment", false);
        sLines.SetRange("Location Code", location);
        sLines.SetRange("No.", itemNo);
        sLines.SetFilter("Outstanding Qty. (Base)", '<>0');
        sLines.SetRange("Shipment Date", 0D, Today);
        sLines.SetRange(Type, Enum::"Sales Line Type"::Item);

        if sLines.FindSet() then
            repeat
                value += sLines."Outstanding Quantity";
            until sLines.Next() = 0;
    end;

    local procedure getItemClass(itemNo: Code[20]) itemClass: text[30]
    var
        ItemProc: Record "LAX DP Procurement Unit";
    begin
        ItemProc.Reset();
        ItemProc.SetRange("Item No.", itemNo);
        if ItemProc.FindSet() then
            repeat
                if ItemProc."Location Code" = 'KS' then begin
                    itemClass := ItemProc."Item Class Description";
                    break;
                end
                else begin
                    itemClass := ItemProc."Item Class Description";
                    break;
                end;

            until ItemProc.Next() = 0
        else
            itemClass := '';

    end;

    local procedure getVendor(item: Record Item) itemVendor: text[30]
    var
        ItemProc: Record "LAX DP Procurement Unit";
    begin
        Clear(procureVendor);
        ItemProc.Reset();
        ItemProc.SetRange("Item No.", item."No.");
        if ItemProc.FindSet() then
            repeat
                case ItemProc."Replenishment Source Type" of
                    Enum::"LAX DP Replen. Source Type"::Vendor:
                        begin
                            itemVendor := ItemProc."Replenishment Source Code";
                            procureVendor := ItemProc."Replenishment Source Code";
                            break;
                        end;
                    Enum::"LAX DP Replen. Source Type"::Location:
                        begin
                            if ItemProc."Location Code" = 'KS' then begin
                                itemVendor := getLocationProcurement(item."No.", ItemProc."Replenishment Source Code");
                                procureVendor := getLocationProcurement(item."No.", ItemProc."Replenishment Source Code");
                                break;
                            end;
                        end;
                    Enum::"LAX DP Replen. Source Type"::Assembly:
                        begin
                            itemVendor := item."Vendor No.";
                            procureVendor := item."Vendor No.";
                            break;
                        end;
                end;
            until ItemProc.Next() = 0
        else begin
            itemVendor := item."Vendor No.";
            procureVendor := '';
        end;

    end;

    local procedure getLocationProcurement(itemNo: Code[20]; locationCode: Code[10]) vendor: text[30]
    var
        ItemProc: Record "LAX DP Procurement Unit";
    begin
        ItemProc.Reset();
        ItemProc.SetRange("Item No.", itemNo);
        ItemProc.SetRange("Location Code", locationCode);
        if ItemProc.FindFirst() then
            vendor := ItemProc."Replenishment Source Code"
        else
            vendor := '';
    end;

    local procedure getExcessAmount(itemNo: Code[20]) amount: Decimal
    var
        ItemSurplus: Record "LAX DP Surplus Inventory Value";
    begin
        ItemSurplus.Reset();
        ItemSurplus.SetRange("Item No.", itemNo);
        ItemSurplus.SetRange("Location Code", 'KS');
        if ItemSurplus.FindFirst() then
            amount := ItemSurplus."Excess Amount"
        else
            amount := 0;
    end;

    local procedure getUom(itemNo: Code[20]): Record "Item Unit of Measure"
    var
        ItemUOM: Record "Item Unit of Measure";
    begin
        ItemUOM.Reset();
        ItemUOM.SetRange("Item No.", itemNo);
        ItemUOM.SetRange(Code, 'EACH');
        if ItemUOM.FindFirst() then
            exit(ItemUOM)
    end;

    local procedure getPurchasePriceDate(item: Record Item) startingDate: Date
    var
        PriceHeader: Record "Price List Header";
    begin
        PriceHeader.Reset();
        PriceHeader.SetRange(Code, procureVendor);
        PriceHeader.SetRange("Source Type", Enum::"Price Source Type"::Vendor);
        if PriceHeader.FindFirst() then
            startingDate := PriceHeader."Starting Date"
        else begin
            PriceHeader.Reset();
            PriceHeader.SetRange(Code, item."Vendor No.");
            PriceHeader.SetRange("Source Type", Enum::"Price Source Type"::Vendor);
            if PriceHeader.FindFirst() then
                startingDate := PriceHeader."Starting Date";
        end;
    end;

    local procedure getPurchasePrice(item: Record Item) Values: List of [Decimal]
    var
        ItemPrice: Record "Price List Line";
    begin
        Clear(minQty);
        ItemPrice.Reset();
        ItemPrice.SetRange("Asset No.", item."No.");
        ItemPrice.SetRange("Product No.", item."No.");
        ItemPrice.SetRange("Assign-to No.", procureVendor);
        ItemPrice.SetRange("Minimum Quantity", 0);
        if ItemPrice.FindFirst() then begin
            Values.Add(ItemPrice."Direct Unit Cost");
            Values.Add(ItemPrice.CoreChargePriceList);
            minQty := ItemPrice."Minimum Quantity";
        end

        else begin
            ItemPrice.Reset();
            ItemPrice.SetRange("Asset No.", item."No.");
            ItemPrice.SetRange("Product No.", item."No.");
            ItemPrice.SetRange("Assign-to No.", procureVendor);
            if ItemPrice.FindFirst() then begin
                Values.Add(ItemPrice."Direct Unit Cost");
                Values.Add(ItemPrice.CoreChargePriceList);
                minQty := ItemPrice."Minimum Quantity";
            end

            else begin
                ItemPrice.Reset();
                ItemPrice.SetRange("Asset No.", item."No.");
                ItemPrice.SetRange("Product No.", item."No.");
                ItemPrice.SetRange("Assign-to No.", item."Vendor No.");
                ItemPrice.SetRange("Minimum Quantity", 0);

                if ItemPrice.FindFirst() then begin
                    Values.Add(ItemPrice."Direct Unit Cost");
                    Values.Add(ItemPrice.CoreChargePriceList);
                    minQty := ItemPrice."Minimum Quantity";
                end
                else begin
                    ItemPrice.Reset();
                    ItemPrice.SetRange("Asset No.", item."No.");
                    ItemPrice.SetRange("Product No.", item."No.");
                    ItemPrice.SetRange("Assign-to No.", item."Vendor No.");

                    if ItemPrice.FindFirst() then begin
                        Values.Add(ItemPrice."Direct Unit Cost");
                        Values.Add(ItemPrice.CoreChargePriceList);
                        minQty := ItemPrice."Minimum Quantity";
                    end
                    else
                        Values.Add(item."Unit Cost");
                    Values.Add(0);
                    minQty := 0
                end
            end
        end;

    end;

    local procedure getItemRef(item: Record Item) itemReference: Code[50]
    var
        ItemRef: Record "Item Reference";
    begin
        ItemRef.Reset();
        ItemRef.SetRange("Item No.", item."No.");
        ItemRef.SetRange("Reference Type No.", procureVendor);
        if ItemRef.FindFirst() then
            itemReference := ItemRef."Reference No."
        else begin
            ItemRef.Reset();
            ItemRef.SetRange("Item No.", item."No.");
            ItemRef.SetRange("Reference Type No.", item."Vendor No.");

            if ItemRef.FindFirst() then
                itemReference := ItemRef."Reference No."
            else
                itemReference := '';
        end;


    end;

    var
        EH: Codeunit SSIExensionHook;
        logHandler: Codeunit PerfionDataLogHandler;
    //logTiming: Codeunit LogTiming;



}