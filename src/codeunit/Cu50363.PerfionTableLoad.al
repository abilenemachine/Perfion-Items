codeunit 50363 PerfionTableLoad
{

    // Add check for ExcessAmount in LAX DP Surplus Inventory Value (14000584)
    trigger OnRun()
    var
        items: Record Item;
        rec: Record PerfionItems;
    begin
        rec.Reset();
        rec.DeleteAll;

        items.SetRange(Type, Enum::"Item Type"::Inventory);
        items.SetRange("Add To Perfion", true);
        //items.SetFilter("No.", 'AMA135881');
        //items.SetFilter("No.", '%1|%2|%3|%4|%5|%6|%7|%8|%9|%10|%11|%12|%13|%14|%15|%16|%17|%18|%19', 'AMX34112', 'AMJD40CABK-L', 'AMJD40UK-L', 'AMJDHK', 'AMJD40CPK', 'AMGLUE', 'AMAH158880', 'HC0935', 'AMX2710106', 'AMAH220019', 'AMAH218490', 'AMHXE36443', 'AMHXE36441', 'AMHXE36439', 'AMHXE80252', 'AMHXE80253', 'AMHXE80254', 'AMHXE36445', 'AMHXE80255');

        if items.FindSet() then
            repeat
                Clear(VendorDateChange);

                rec.Init();
                rec."No." := items."No.";
                rec.Description := items.Description;
                rec.GTIN := items.GTIN;
                rec.Blocked := items.Blocked;
                rec."Replenishment System" := items."Replenishment System";
                rec."Gen. Prod. Posting Group" := getCondition(items);
                rec."Item Category Code" := items."Item Category Code";
                rec."Drop Ship" := items."Drop Ship";

                rec.Length := getUom(items."No.", 'Length');
                rec.Width := getUom(items."No.", 'Width');
                rec.Height := getUom(items."No.", 'Height');
                rec.Weight := getUom(items."No.", 'Weight');
                rec.Cubage := getUom(items."No.", 'Cubage');
                rec.NMFC := items."IWX LTL NMFC";
                rec."Freight Density" := items."IWX LTL Freight Density";

                rec."Item Class Description" := getItemClass(items."No.");

                rec."Vendor No." := getVendor(items);
                rec."Vendor Date Changed" := VendorDateChange;

                rec."Unit Cost" := items."Unit Cost";
                rec."Vendor Cost" := getPurchasePrice(items);

                rec."Excess Amount" := getExcessAmount(items."No.");

                rec."Reference No." := getItemRef(items);

                rec.Demand := EH.GetUsageLast12Months(items."No.");

                items.CalcFields("Assembly BOM");

                if items."Assembly BOM" then begin
                    rec."Quantity KS" := getBomComponents(items."No.", 'KS');
                    rec."Quantity SC" := getBomComponents(items."No.", 'SC');
                    rec."Quantity SD" := getBomComponents(items."No.", 'SD');
                    rec."Quantity MT" := getBomComponents(items."No.", 'MT');
                end
                else begin
                    rec."Quantity KS" := getQty(items."No.", 'KS');
                    rec."Quantity SC" := getQty(items."No.", 'SC');
                    rec."Quantity SD" := getQty(items."No.", 'SD');
                    rec."Quantity MT" := getQty(items."No.", 'MT');
                end;

                rec.Insert();
            until items.Next() = 0
    end;

    var
        procureVendor: Code[20];
        VendorDateChange: Date;
        minQty: Decimal;


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
        exit(qtyMin);

    end;

    local procedure getQty(itemNo: Code[20]; location: code[10]): Decimal
    var
        wEntryBins: Record "Warehouse Entry";
        bContents: Record "Bin Content";
        sLines: Record "Sales Line";
        assyLines: Record "Assembly Line";
        iLedger: Record "Item Ledger Entry";
        item: Record Item;
        tLines: Record "Transfer Line";
        pOrdCompLines: Record "Prod. Order Component";

        qtyOnSalesOrder: Decimal;
        qtyOnAssy: Decimal;
        qtyiLedger: Decimal;
        qtyBinContents: Decimal;
        qtyFinal: Decimal;
        qtyProduction: Decimal;
        qtyTransfer: Decimal;

    begin
        qtyOnSalesOrder := 0;
        qtyBinContents := 0;
        qtyOnAssy := 0;
        qtyiLedger := 0;
        qtyFinal := 0;
        qtyProduction := 0;
        qtyTransfer := 0;

        tLines.Reset();
        tLines.SetRange("Item No.", itemNo);
        tLines.SetRange("Transfer-from Code", location);
        tLines.SetFilter("Outstanding Qty. (Base)", '<>0');
        tLines.SetRange("Shipment Date", 0D, Today);
        if tLines.CalcSums("Outstanding Quantity") then
            qtyTransfer := tLines."Outstanding Quantity";

        pOrdCompLines.Reset();
        pOrdCompLines.SetRange("Item No.", itemNo);
        pOrdCompLines.SetRange("Location Code", location);
        pOrdCompLines.SetFilter(Status, '%1|%2', Enum::"Production Order Status"::Planned, Enum::"Production Order Status"::Released);
        pOrdCompLines.SetFilter("Remaining Qty. (Base)", '<>0');
        pOrdCompLines.SetRange("Due Date", 0D, Today);
        if pOrdCompLines.CalcSums("Remaining Quantity") then
            qtyProduction := pOrdCompLines."Remaining Quantity";

        wEntryBins.Reset();
        wEntryBins.SetRange("Item No.", itemNo);
        wEntryBins.SetRange("Location Code", location);
        //wEntryBins.SetFilter("Bin Code", '%1|%2|%3|%4|%5', 'QC', 'QA', 'RTV', 'RTV BIN', 'DISPOSAL');
        //Filter for dedicated bins AND Bin Code SHIP
        wEntryBins.SetFilter("Bin Code", '%1', 'SHIP');
        if wEntryBins.CalcSums(Quantity) then
            qtyBinContents := wEntryBins.Quantity;

        wEntryBins.Reset();
        wEntryBins.SetRange("Item No.", itemNo);
        wEntryBins.SetRange("Location Code", location);
        //wEntryBins.SetFilter("Bin Code", '%1|%2|%3|%4|%5', 'QC', 'QA', 'RTV', 'RTV BIN', 'DISPOSAL');
        //Filter for dedicated bins AND Bin Code SHIP
        wEntryBins.SetFilter(Dedicated, 'True');
        if wEntryBins.CalcSums(Quantity) then
            qtyBinContents := wEntryBins.Quantity;

        /*
                        BinContent.Reset();
                        BinContent.SetRange("Location Code", LocationCode);
                        BinContent.SetRange("Item No.", BOMComponent."No.");
                        BinContent.SetFilter("Bin Code", '%1|%2|%3', 'QC BIN', 'RTV BIN', 'DISPOSAL');
                        if BinContent.FindSet()then repeat BinContent.CalcFields("Quantity (Base)");
                                QtyUnSellableBin+=BinContent."Quantity (Base)";
                            until BinContent.Next = 0;
                        BinContent.Reset();
                        BinContent.SetRange("Location Code", LocationCode);
                        BinContent.SetRange("Item No.", BOMComponent."No.");
                        BinContent.SetFilter("Bin Code", '<>%1&<>%2&<>%3', 'QC BIN', 'RTV BIN', 'DISPOSAL');
                        BinContent.SetRange(Dedicated, true);
                        if BinContent.FindSet()then repeat BinContent.CalcFields("Quantity (Base)");
                                QtyUnSellableBin+=BinContent."Quantity (Base)";
                            until BinContent.Next = 0;

        */

        iLedger.Reset();
        iLedger.SetRange("Item No.", itemNo);
        iLedger.SetRange("Location Code", location);
        if iLedger.CalcSums(Quantity) then
            qtyiLedger := iLedger.Quantity;

        assyLines.Reset();
        assyLines.SetRange("Document Type", Enum::"Assembly Document Type"::Order);
        assyLines.SetRange(Type, Enum::"BOM Component Type"::Item);
        assyLines.SetRange("Location Code", location);
        assyLines.SetRange("No.", itemNo);

        if assyLines.FindSet() then
            repeat
                qtyOnAssy := qtyOnAssy + assyLines."Remaining Quantity";
            until assyLines.Next() = 0;

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
                qtyOnSalesOrder := qtyOnSalesOrder + sLines."Outstanding Quantity";
            until sLines.Next() = 0;

        qtyFinal := qtyiLedger - (qtyOnSalesOrder + qtyOnAssy + qtyBinContents + qtyTransfer + qtyProduction);

        if qtyFinal < 0 then
            qtyFinal := 0;

        exit(qtyFinal);

    end;

    local procedure getVendorDateChange(itemNo: Code[20]) dateChanged: Date
    var
        ChangeLog: Record "Change Log Entry";
    begin
        ChangeLog.Reset();
        ChangeLog.SetRange("Table No.", 14000555);
        ChangeLog.SetRange("Primary Key Field 1 Value", 'KS');
        ChangeLog.SetRange("Field Log Entry Feature", Enum::"Field Log Entry Feature"::"Change Log");

        if ChangeLog.FindSet() then
            repeat
                if ChangeLog."Primary Key Field 2 Value" = itemNo then
                    dateChanged := DT2Date(ChangeLog."Date and Time");
            until ChangeLog.Next() = 0;

        //ChangeLog.SetRange("Primary Key Field 2 Value", itemNo);
        //ChangeLog.SetCurrentKey("Table No.", "Date and Time");
        //ChangeLog.SetAscending("Date and Time", false);
        //if ChangeLog.FindFirst() then
        //dateChanged := DT2Date(ChangeLog."Date and Time");
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

    local procedure getUom(itemNo: Code[20]; type: text[10]) rValue: Decimal
    var
        ItemUOM: Record "Item Unit of Measure";
    begin
        ItemUOM.Reset();
        ItemUOM.SetRange("Item No.", itemNo);
        ItemUOM.SetRange(Code, 'EACH');
        if ItemUOM.FindFirst() then
            case type of
                'Length':
                    rValue := ItemUOM.Length;
                'Width':
                    rValue := ItemUOM.Width;
                'Height':
                    rValue := ItemUOM.Height;
                'Weight':
                    rValue := ItemUOM.Weight;
                'Cubage':
                    rValue := ItemUOM.Cubage;
            end;
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

    local procedure getPurchasePrice(item: Record Item) purchasePrice: Decimal
    var
        ItemPrice: Record "Price List Line";
    begin
        ItemPrice.Reset();
        ItemPrice.SetRange("Asset No.", item."No.");
        ItemPrice.SetRange("Product No.", item."No.");
        ItemPrice.SetRange("Assign-to No.", procureVendor);
        ItemPrice.SetRange("Minimum Quantity", 0);
        if ItemPrice.FindFirst() then begin
            purchasePrice := ItemPrice."Direct Unit Cost";
            minQty := ItemPrice."Minimum Quantity";
        end

        else begin
            ItemPrice.Reset();
            ItemPrice.SetRange("Asset No.", item."No.");
            ItemPrice.SetRange("Product No.", item."No.");
            ItemPrice.SetRange("Assign-to No.", procureVendor);
            if ItemPrice.FindFirst() then begin
                purchasePrice := ItemPrice."Direct Unit Cost";
                minQty := ItemPrice."Minimum Quantity";
            end

            else begin
                ItemPrice.Reset();
                ItemPrice.SetRange("Asset No.", item."No.");
                ItemPrice.SetRange("Product No.", item."No.");
                ItemPrice.SetRange("Assign-to No.", item."Vendor No.");
                ItemPrice.SetRange("Minimum Quantity", 0);

                if ItemPrice.FindFirst() then begin
                    purchasePrice := ItemPrice."Direct Unit Cost";
                    minQty := ItemPrice."Minimum Quantity";
                end
                else begin
                    ItemPrice.Reset();
                    ItemPrice.SetRange("Asset No.", item."No.");
                    ItemPrice.SetRange("Product No.", item."No.");
                    ItemPrice.SetRange("Assign-to No.", item."Vendor No.");

                    if ItemPrice.FindFirst() then begin
                        purchasePrice := ItemPrice."Direct Unit Cost";
                        minQty := ItemPrice."Minimum Quantity";
                    end
                    else
                        purchasePrice := item."Unit Cost";
                    minQty := 0
                end
            end
        end


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


}