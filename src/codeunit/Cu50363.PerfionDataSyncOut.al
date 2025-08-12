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
        Profiler: Codeunit AbileneProfiler;
        t: Time;
        tOnRun: Time;     // <- outer scope timer
        startTime, endTime : Time;
        executionTime: Duration;
        logManager: Codeunit LogManager;
    begin
        startTime := Time;
        Profiler.BeginRun(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync Out", true, 250); // enable=true, log details only if >=200ms
        Profiler.Start('onRun', tOnRun);
        recPerfionItems.Reset();
        recPerfionItems.DeleteAll();
        InitUnsellableFilters();

        // Item filter for ~5k items
        // AM10* (651), AM11* (686), AM12* (753), AM13* (1108), AM14* (385),
        // AM18* (587), AM19* (825)  → total ≈ 4,995
        //bcItems.SetFilter("No.", 'AM10*|AM11*|AM12*|AM13*|AM14*|AM18*|AM19*');

        bcItems.SetRange(Type, Enum::"Item Type"::Inventory);
        bcItems.SetRange(PerfionSync, Enum::PerfionSyncStatus::Accepted);
        //bcItems.SetFilter("No.", 'AMAR26497-U');
        //bcItems.SetFilter("No.", '%1|%2|%3|%4|%5|%6|%7|%8|%9|%10|%11|%12|%13|%14|%15|%16|%17|%18|%19', 'AMX34112', 'AMJD40CABK-L', 'AMJD40UK-L', 'AMJDHK', 'AMJD40CPK', 'AMSS10012', 'AMAH158880', 'HC0935', 'AMX2710106', 'AMAH220019', 'AMAH218490', 'AMHXE36443', 'AMHXE36441', 'AMHXE36439', 'AMHXE80252', 'AMHXE80253', 'AMHXE80254', 'AMHXE36445', 'AMHXE80255');

        bcItems.SetLoadFields(
            "No.", Description, GTIN, Blocked, "Replenishment System",
            "Gen. Prod. Posting Group", "Item Category Code", "Drop Ship",
            "Sales Unit of Measure", "Purch. Unit of Measure", "IWX LTL NMFC",
            "IWX LTL Freight Density", Oversize, "Vendor No.", "Unit Cost",
            application, userNotes, "Country/Region of Origin Code",
            "Last DateTime Modified", "Assembly BOM"
        );

        InitItemsInScope(bcItems);
        InitUnsellableBins(); // builds the bin set
        Profiler.Start('PreloadUnsellableTotals', t);
        PreloadUnsellableTotals('KS|SC|SD|MT'); // scans Bin Content once and fills totals
        Profiler.Stop('PreloadUnsellableTotals', t, '', '');

        bcItems.SetAutoCalcFields("Assembly BOM");

        if bcItems.FindSet() then
            repeat
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
                Profiler.Start('getUom', t);
                ItemUOM := getUom(bcItems."No.");
                recPerfionItems.Length := ItemUOM.Length;
                recPerfionItems.Width := ItemUOM.Width;
                recPerfionItems.Height := ItemUOM.Height;
                recPerfionItems.Weight := ItemUOM.Weight;
                recPerfionItems.Cubage := ItemUOM.Cubage;
                Profiler.Stop('getUom', t, bcItems."No.", '');

                recPerfionItems."Qty per UOM Purch" := getQtyPerUom(bcItems."No.", bcItems."Purch. Unit of Measure");
                recPerfionItems."Qty per UOM Sales" := getQtyPerUom(bcItems."No.", bcItems."Sales Unit of Measure");

                recPerfionItems.NMFC := bcItems."IWX LTL NMFC";
                recPerfionItems."Freight Density" := bcItems."IWX LTL Freight Density";
                recPerfionItems.Oversize := getOversize(bcItems);

                recPerfionItems."Item Class Description" := getItemClass(bcItems."No.");
                Profiler.Start('getVendor', t);
                recPerfionItems."Vendor No." := getVendor(bcItems);
                Profiler.Stop('getVendor', t, bcItems."No.", '');

                recPerfionItems."Unit Cost" := bcItems."Unit Cost";

                Profiler.Start('getPurchasePrice', t);
                Values := getPurchasePrice(bcItems);
                Profiler.Stop('getPurchasePrice', t, bcItems."No.", '');
                recPerfionItems."Vendor Cost" := Values.Get(1);
                recPerfionItems."Vendor Core" := Values.Get(2);

                recPerfionItems."Minimum Qty" := minQty;

                recPerfionItems."Excess Amount" := getExcessAmount(bcItems."No.");

                recPerfionItems."Reference No." := getItemRef(bcItems);

                recPerfionItems.application := bcItems.application;
                recPerfionItems.userNotes := bcItems.userNotes;

                Profiler.Start('GetUsageLast12Months', t);
                recPerfionItems.demand12months := GetUsageLast12Months(bcItems."No.");
                Profiler.Stop('GetUsageLast12Months', t, bcItems."No.", '');
                recPerfionItems.demand1month := GetUsageLast1Month(bcItems."No.");

                recPerfionItems.CountryOfOrigin := getCountryOfOrigin(bcItems);

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

                Profiler.Start('recPerfionItems.Insert', t);
                recPerfionItems.Insert();
                Profiler.Stop('recPerfionItems.Insert', t, bcItems."No.", '');
                changeCount += 1;

            until bcItems.Next() = 0;

        if perfionDataSync.Get() then begin
            perfionDataSync.LastSync := CreateDateTime(Today, Time);
            perfionDataSync.Processed := changeCount;
            perfionDataSync.Modify();
        end;

        endTime := Time;
        executionTime := endTime - startTime;
        logManager.logInfo(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync Out", 'OnRun complete', '', Format(executionTime));

        Profiler.Stop('onRun', tOnRun, '', '');
        Profiler.Flush();
    end;

    var
        procureVendor: Code[20];
        minQty: Decimal;
        UnsellableBinFilterIn: Text;   // e.g. 'BIN1|BIN2|...'
        UnsellableBinFilterNotIn: Text; // e.g. '<>BIN1&<>BIN2&...'
        IsUnsellableInit: Boolean;
        UnsellableBins: Dictionary of [Code[20], Boolean]; // set of bin codes
        UnsellableTotals: Dictionary of [Text, Decimal];   // key: ItemNo|Location
        ItemsInScope: Dictionary of [Code[20], Boolean];   // items we’re processing
        UnsellableCacheReady: Boolean;

    local procedure InitUnsellableFilters()
    var
        UB: Record "Unsellable Bins";
    begin
        if IsUnsellableInit then
            exit;

        Clear(UnsellableBinFilterIn);
        Clear(UnsellableBinFilterNotIn);

        if UB.FindSet() then
            repeat
                if UnsellableBinFilterIn <> '' then
                    UnsellableBinFilterIn += '|';
                UnsellableBinFilterIn += UB."Bin Code";

                if UnsellableBinFilterNotIn <> '' then
                    UnsellableBinFilterNotIn += '&';
                UnsellableBinFilterNotIn += '<>' + UB."Bin Code";
            until UB.Next() = 0;

        IsUnsellableInit := true;
    end;

    local procedure InitItemsInScope(var bcItems: Record Item)
    begin
        Clear(ItemsInScope);
        if bcItems.FindSet() then
            repeat
                if not ItemsInScope.ContainsKey(bcItems."No.") then
                    ItemsInScope.Add(bcItems."No.", true);
            until bcItems.Next() = 0;
        bcItems.FindFirst(); // rewind for main processing
    end;

    local procedure InitUnsellableBins()
    var
        UB: Record "Unsellable Bins";
    begin
        if UnsellableCacheReady then exit;
        Clear(UnsellableBins);
        if UB.FindSet() then
            repeat
                if not UnsellableBins.ContainsKey(UB."Bin Code") then
                    UnsellableBins.Add(UB."Bin Code", true);
            until UB.Next() = 0;
    end;

    local procedure PreloadUnsellableTotals(LocationFilter: Text)
    var
        BC: Record "Bin Content";
        syncKey: Text[60];
        qty: Decimal;
        isUnsellable: Boolean;
        itemInScope: Boolean;
    begin
        Clear(UnsellableTotals);

        BC.Reset();
        // If your runtime supports SetLoadFields, keep it; otherwise remove the next line.
        BC.SetLoadFields("Item No.", "Location Code", "Bin Code", Dedicated, Quantity);
        BC.SetAutoCalcFields(Quantity);

        if LocationFilter <> '' then
            BC.SetFilter("Location Code", LocationFilter);

        if BC.FindSet() then
            repeat
                // (old 'continue' replaced by an if-guard)
                itemInScope := ItemsInScope.ContainsKey(BC."Item No.");
                if itemInScope then begin
                    // Mark as unsellable if in the explicit list OR dedicated (adjust to your rule)
                    isUnsellable := UnsellableBins.ContainsKey(BC."Bin Code") or (BC.Dedicated and not UnsellableBins.ContainsKey(BC."Bin Code"));

                    if isUnsellable then begin
                        syncKey := Format(BC."Item No.") + '|' + Format(BC."Location Code");

                        if UnsellableTotals.ContainsKey(syncKey) then begin
                            qty := UnsellableTotals.Get(syncKey);
                            UnsellableTotals.Set(syncKey, qty + BC.Quantity);
                        end else
                            UnsellableTotals.Add(syncKey, BC.Quantity);
                    end;
                end;
            until BC.Next() = 0;

        UnsellableCacheReady := true;
    end;


    local procedure getCountryOfOrigin(item: Record Item): Code[20]
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
        t: Time;
        Profiler: Codeunit AbileneProfiler;
    begin
        Profiler.Start('getBomComponents', t);
        qtyPer := 0;
        qty := 0;
        qtyMin := 0;
        qtyInit := 0;

        bComponent.Reset();
        bComponent.SetRange("Parent Item No.", itemNo);
        bComponent.SetRange(Selection, bComponent.Selection::Mandatory);
        bComponent.SetFilter("Quantity per", '>%1', 0);

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
        Profiler.Stop('getBomComponents', t, itemNo, location);
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
        t: Time;
        Profiler: Codeunit AbileneProfiler;

    begin
        Profiler.Start('getQty', t);
        qtyOnSalesOrder := 0;
        qtyUnsellableBin := 0;
        qtyOnAssy := 0;
        qtyiLedger := 0;
        qtyFinal := 0;
        qtyProduction := 0;
        qtyTransfer := 0;

        // Sales orders
        Profiler.Start('qty.SalesLine', t);
        qtyOnSalesOrder := getSalesLineQty(itemNo, location);
        Profiler.Stop('qty.SalesLine', t, itemNo, location);

        // Assembly
        Profiler.Start('qty.Assembly', t);
        qtyOnAssy := getAssemblyQty(itemNo, location);
        Profiler.Stop('qty.Assembly', t, itemNo, location);

        // Unsellable bins
        Profiler.Start('qty.Unsellable', t);
        qtyUnsellableBin := getUnsellableQty(itemNo, location);
        Profiler.Stop('qty.Unsellable', t, itemNo, location);

        // Transfers
        Profiler.Start('qty.Transfer', t);
        qtyTransfer := getTransferQty(itemNo, location);
        Profiler.Stop('qty.Transfer', t, itemNo, location);

        // Production
        Profiler.Start('qty.Production', t);
        qtyProduction := getProductionQty(itemNo, location);
        Profiler.Stop('qty.Production', t, itemNo, location);

        // Ledger
        Profiler.Start('qty.Ledger', t);
        qtyiLedger := getLedgerQty(itemNo, location);
        Profiler.Stop('qty.Ledger', t, itemNo, location);

        qtyFinal := qtyiLedger - (qtyOnSalesOrder + qtyOnAssy + qtyUnsellableBin + qtyTransfer + qtyProduction);

        if qtyFinal < 0 then
            qtyFinal := 0;

        Profiler.Stop('getQty', t, itemNo, location);
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

    procedure getUnsellableQty(itemNo: Code[20]; location: Code[10]) value: Decimal
    var
        syncKey: Text[60];
    begin
        syncKey := Format(itemNo) + '|' + Format(location);
        if UnsellableCacheReady and UnsellableTotals.ContainsKey(syncKey) then
            exit(UnsellableTotals.Get(syncKey));
        exit(0);
    end;

    /*
        procedure getUnsellableQty(itemNo: Code[20]; location: Code[10]) value: Decimal
        var
            binContent: Record "Bin Content";
        begin

            // Calculate FlowField automatically when we read the record
            binContent.SetAutoCalcFields(Quantity);

            // 1) Explicit unsellable bins
            if UnsellableBinFilterIn <> '' then begin
                binContent.Reset();
                binContent.SetLoadFields("Item No.", "Location Code", "Bin Code", Quantity);
                binContent.SetRange("Item No.", itemNo);
                binContent.SetRange("Location Code", location);
                binContent.SetFilter("Bin Code", UnsellableBinFilterIn);

                if binContent.FindSet() then
                    repeat
                        value += binContent.Quantity;   // Quantity is FlowField, already calculated
                    until binContent.Next() = 0;
            end;

            // 2) Dedicated bins that are NOT in the unsellable list
            binContent.Reset();
            binContent.SetLoadFields("Item No.", "Location Code", "Bin Code", Dedicated, Quantity);
            binContent.SetRange("Item No.", itemNo);
            binContent.SetRange("Location Code", location);
            if UnsellableBinFilterNotIn <> '' then
                binContent.SetFilter("Bin Code", UnsellableBinFilterNotIn);
            binContent.SetRange(Dedicated, true);

            if binContent.FindSet() then
                repeat
                    value += binContent.Quantity;
                until binContent.Next() = 0;
        end;

    */

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
        assyLines.SetRange("Document Type", assyLines."Document Type"::Order);
        assyLines.SetRange(Type, assyLines.Type::Item);
        assyLines.SetRange("Location Code", location);
        assyLines.SetRange("No.", itemNo);

        if assyLines.CalcSums("Remaining Quantity") then
            value := assyLines."Remaining Quantity";
    end;

    procedure getSalesLineQty(itemNo: Code[20]; location: code[10]) value: Decimal
    var
        sLines: Record "Sales Line";
    begin
        sLines.Reset();
        sLines.SetRange("Document Type", Enum::"Sales Document Type"::Order);
        sLines.SetRange(Type, sLines.Type::Item);
        sLines.SetRange("Drop Shipment", false);
        sLines.SetRange("Location Code", location);
        sLines.SetRange("No.", itemNo);
        sLines.SetFilter("Outstanding Qty. (Base)", '<>0');
        sLines.SetRange("Shipment Date", 0D, Today);

        if sLines.CalcSums("Outstanding Quantity") then
            value := sLines."Outstanding Quantity";

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
        // 1) Vendor direct
        ItemProc.Reset();
        ItemProc.SetRange("Item No.", item."No.");
        ItemProc.SetRange("Replenishment Source Type", ItemProc."Replenishment Source Type"::Vendor);
        if ItemProc.FindFirst() then begin
            itemVendor := ItemProc."Replenishment Source Code";
            procureVendor := itemVendor;
            exit;
        end;

        // 2) Location KS
        ItemProc.Reset();
        ItemProc.SetRange("Item No.", item."No.");
        ItemProc.SetRange("Replenishment Source Type", ItemProc."Replenishment Source Type"::Location);
        ItemProc.SetRange("Location Code", 'KS');
        if ItemProc.FindFirst() then begin
            itemVendor := getLocationProcurement(item."No.", ItemProc."Replenishment Source Code");
            procureVendor := itemVendor;
            exit;
        end;

        // 3) Assembly fallback
        ItemProc.Reset();
        ItemProc.SetRange("Item No.", item."No.");
        ItemProc.SetRange("Replenishment Source Type", ItemProc."Replenishment Source Type"::Assembly);
        if ItemProc.FindFirst() then begin
            itemVendor := item."Vendor No.";
            procureVendor := itemVendor;
            exit;
        end;

        // 4) Final fallback
        itemVendor := item."Vendor No.";
        procureVendor := '';

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

    local procedure getQtyPerUom(itemNo: Code[20]; uomCode: Code[10]): Decimal
    var
        ItemUOM: Record "Item Unit of Measure";
    begin
        ItemUOM.Reset();
        ItemUOM.SetRange("Item No.", itemNo);
        ItemUOM.SetRange(Code, uomCode);
        if ItemUOM.FindFirst() then
            exit(ItemUOM."Qty. per Unit of Measure")
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

    local procedure GetUsageLast12Months(ItemNo: Code[20]): Decimal
    var
        LAXDPUsageLedEntry: Record "LAX DP Usage Ledger Entry";
        startDate: date;
        endDate: date;
        TotalUsageQty: Decimal;
    begin
        TotalUsageQty := 0;
        EndDate := CALCDATE('-CM-1D', Today);
        StartDate := CALCDATE('-12M', EndDate);
        LAXDPUsageLedEntry.Reset();
        LAXDPUsageLedEntry.SetCurrentKey("Item No.", "Entry Type", "Usage Date");
        LAXDPUsageLedEntry.SetRange("Item No.", ItemNo);
        LAXDPUsageLedEntry.SetRange("Entry Type", LAXDPUsageLedEntry."Entry Type"::Sale);
        LAXDPUsageLedEntry.SetRange("USAGE date", startDate, endDate);
        if LAXDPUsageLedEntry.CalcSums(Quantity) then
            exit(-LAXDPUsageLedEntry.Quantity);
        exit(0);
    end;

    local procedure GetUsageLast1Month(ItemNo: Code[20]): Decimal
    var
        LAXDPUsageLedEntry: Record "LAX DP Usage Ledger Entry";
        startDate: date;
        endDate: date;
        TotalUsageQty: Decimal;
    begin
        TotalUsageQty := 0;
        EndDate := CALCDATE('-CM-1D', Today);
        StartDate := CALCDATE('-1M', EndDate);
        LAXDPUsageLedEntry.Reset();
        LAXDPUsageLedEntry.SetCurrentKey("Item No.", "Entry Type", "Usage Date");
        LAXDPUsageLedEntry.SetRange("Item No.", ItemNo);
        LAXDPUsageLedEntry.SetRange("Entry Type", LAXDPUsageLedEntry."Entry Type"::Sale);
        LAXDPUsageLedEntry.SetRange("USAGE date", startDate, endDate);
        if LAXDPUsageLedEntry.CalcSums(Quantity) then
            exit(-1 * LAXDPUsageLedEntry.Quantity);
        exit(0);
    end;

    procedure CalcAvailableQty(ItemNo: code[20]; LocCode: code[20]): Decimal
    var
        ILE: Record "Item Ledger Entry";
    begin
        ILE.Reset();
        ILE.SetRange("Item No.", ItemNo);
        IF LocCode <> '' then ILE.SetRange("Location Code", LocCode);
        ILE.CalcSums(Quantity);
        exit(ILE.Quantity);
    end;


}