codeunit 50366 PerfionPriceSync
{
    trigger OnRun()
    var
        perfionPriceSync: Record PerfionPriceSync;
    begin
        perfionPriceSync.Get();
        //LOGIC - Update the last sync time
        perfionPriceSync.LastSync := CreateDateTime(Today, Time);
        perfionPriceSync.Modify();

        //LOGIC - Get the Perfion Token & register variables
        startPerfionRequest();

    end;

    local procedure startPerfionRequest()
    var
        CallResponse: Text;
        Content: Text;
        ErrorList: List of [Text];
        ErrorListMsg: Text;
        perfionConfig: Record PerfionConfig;
    begin
        perfionConfig.Get();
        manualDate := perfionConfig."Manual Date";
        if manualDate = 0D then
            useManualDate := false
        else
            useManualDate := true;

        Content := GenerateQueryContent();

        if not apiHandler.perfionPostRequest(CallResponse, ErrorList, Content) then begin
            logHandler.enterLog(Process::"Price Sync", 'perfionPostRequest', '', GetLastErrorText());
            exit;
        end;

        if ErrorList.Count > 0 then begin
            foreach ErrorListMsg in ErrorList do begin
                logHandler.enterLog(Process::"Price Sync", 'perfionPostRequest', '', ErrorListMsg);
            end;
            exit;
        end;

        processPerfionResponse(CallResponse)
    end;

    local procedure processPerfionResponse(response: Text)
    var
        responseObject: JsonObject;
        dataToken: JsonToken;
        totalToken: JsonToken;
        itemsToken: JsonToken;
        valuesToken: JsonToken;
        valueItemToken: JsonToken;
        valuePriceToken: JsonToken;
        featureToken: JsonToken;
        itemNumToken: JsonToken;
        itemDateModified: JsonToken;
        itemPriceToken: JsonToken;
        itemPriceTypeToken: JsonToken;
        featureId: JsonToken;

        modifiedDate: Date;
        perfionPriceSync: Record PerfionPriceSync;
        itemNum: Code[20];
        priceType: Text;
        priceAmount: Decimal;
        modifiedDateTime: DateTime;
        modifiedDateTimeText: Text;
        arrPrice: array[5] of Decimal;
        arrDateTime: array[5] of Text;
        arrPriceType: array[5] of Text;
        index: Integer;

    begin
        changeCount := 0;
        arrPriceType[1] := 'W05Calculated';
        arrPriceType[2] := 'W1Calculated';
        arrPriceType[3] := 'W2Calculated';
        arrPriceType[4] := 'W3Calculated';
        arrPriceType[5] := 'W4Calculated';
        if responseObject.ReadFrom(response) then begin
            responseObject.SelectToken('Data', dataToken);
            dataToken.SelectToken('totalCount', totalToken);
            dataToken.SelectToken('Items', itemsToken);

            foreach itemsToken in itemsToken.AsArray() do begin
                itemsToken.SelectToken('Values', valuesToken);
                if valuesToken.AsArray().Count > 0 then begin
                    valuesToken.AsArray().Get(0, valueItemToken);
                    valueItemToken.SelectToken('value', itemNumToken);

                    Clear(itemNum);
                    itemNum := itemNumToken.AsValue().AsCode();

                    if checkItem(itemNum) then begin

                        foreach valuesToken in valuesToken.AsArray() do begin
                            valuesToken.SelectToken('featureId', featureId);
                            if featureId.AsValue().AsInteger() <> 100 then begin

                                Clear(modifiedDateTimeText);
                                Clear(modifiedDate);

                                valuesToken.SelectToken('modifiedDate', itemDateModified);
                                modifiedDate := DT2Date(itemDateModified.AsValue().AsDateTime());

                                valuesToken.SelectToken('value', itemPriceToken);
                                valuesToken.SelectToken('featureName', itemPriceTypeToken);
                                priceType := itemPriceTypeToken.AsValue().AsText();
                                priceAmount := itemPriceToken.AsValue().AsDecimal();
                                modifiedDateTime := itemDateModified.AsValue().AsDateTime();

                                if modifiedDate = 0D then
                                    modifiedDateTimeText := ''
                                else
                                    modifiedDateTimeText := format(getLocalDateTime(modifiedDateTime));

                                case priceType of
                                    'RetailPrice':
                                        updatePriceListLine(itemNum, priceAmount, priceType, modifiedDateTimeText);
                                    'Wholesale':
                                        updatePriceListLine(itemNum, priceAmount, priceType, modifiedDateTimeText);
                                    'W05Calculated':
                                        arrPrice[1] := priceAmount;
                                    'W1Calculated':
                                        arrPrice[2] := priceAmount;
                                    'W2Calculated':
                                        arrPrice[3] := priceAmount;
                                    'W3Calculated':
                                        arrPrice[4] := priceAmount;
                                    'W4Calculated':
                                        arrPrice[5] := priceAmount;
                                    'W05MaxDiscount':
                                        arrDateTime[1] := modifiedDateTimeText;
                                    'W1MaxDiscount':
                                        arrDateTime[2] := modifiedDateTimeText;
                                    'W2MaxDiscount':
                                        arrDateTime[3] := modifiedDateTimeText;
                                    'W3MaxDiscount':
                                        arrDateTime[4] := modifiedDateTimeText;
                                    'W4MaxDiscount':
                                        arrDateTime[5] := modifiedDateTimeText;
                                end;


                            end;
                        end;

                        for index := 1 to 5 do
                            updatePriceListLine(itemNum, arrPrice[index], arrPriceType[index], arrDateTime[index]);
                    end;
                end
            end;
        end;
        perfionPriceSync.Get();
        perfionPriceSync.Processed := changeCount;
        perfionPriceSync.TotalCount := totalToken.AsValue().AsInteger();
        perfionPriceSync.Modify();

    end;

    local procedure checkItem(itemNo: Code[20]): Boolean
    var
        recItem: Record Item;

    begin
        if Text.StrLen(itemNo) > 20 then begin
            logHandler.enterLog(Process::"Price Sync", 'checkItem', itemNo, 'Item Num too long');
            exit(false);
        end;
        recItem.Reset();

        if not recItem.Get(itemNo) then begin
            logHandler.enterLog(Process::"Price Sync", 'checkItem', itemNo, 'Item not in BC');
            exit(false);
        end
        else if recItem.Blocked then begin
            logHandler.enterLog(Process::"Price Sync", 'checkItem', itemNo, 'Item Blocked in BC');
            exit(false);
        end
        else
            exit(true);
    end;

    local procedure updatePriceListLine(itemNo: Code[20]; price: Decimal; priceGroup: Text; modified: Text)
    var
        priceList: Record "Price List Line";
        originalPrice: Decimal;
        perfionPriceSync: Record PerfionPriceSync;
        currentPriceList: Code[20];

    begin
        perfionPriceSync.Get();
        currentPriceList := perfionPriceSync.SalesPriceList;

        priceList.Reset();
        priceList.SetRange("Price List Code", currentPriceList);
        priceList.SetFilter("Product No.", itemNo);
        priceList.SetFilter("Source No.", getPriceGroup(priceGroup));
        if priceList.FindFirst() then begin
            if priceList."Unit Price" <> price then begin
                originalPrice := priceList."Unit Price";
                priceList."Unit Price" := price;

                if priceList.Modify() then begin
                    priceLogHandler.logItemUpdate(itemNo, originalPrice, price, priceList."Source No.", modified);
                    changeCount += 1;
                end
                else
                    logHandler.enterLog(Process::"Price Sync", 'Error Updating Price', itemNo, GetLastErrorText());
            end;
        end
        else begin
            priceList.Reset();
            priceList.Init();
            priceList."Price List Code" := currentPriceList;
            priceList."Source Type" := "Price Source Type"::"All Customers";
            priceList."Source No." := getPriceGroup(priceGroup);
            priceList."Asset Type" := "Price Asset Type"::Item;
            priceList."Asset No." := itemNo;
            priceList."Starting Date" := getPriceListStartDate(currentPriceList);
            priceList."Unit of Measure Code" := 'EACH';
            priceList."Amount Type" := "Price Amount Type"::Price;
            priceList."Price Type" := "Price Type"::Sale;
            priceList.Status := "Price Status"::Active;
            priceList."Unit Price" := price;
            priceList."Source Group" := "Price Source Group"::Customer;
            priceList."Product No." := itemNo;
            priceList."Assign-to No." := getPriceGroup(priceGroup);

            if priceList.Insert() then begin
                priceLogHandler.logItemUpdate(itemNo, originalPrice, price, priceList."Source No.", modified);
                changeCount += 1;
            end
            else
                logHandler.enterLog(Process::"Price Sync", 'Error Adding Price', itemNo, GetLastErrorText());
        end;
    end;

    local procedure getPriceListStartDate(SalesPriceList: Code[20]): Date
    var
        priceList: Record "Price List Line";

    begin
        priceList.Reset();
        priceList.SetRange("Price List Code", SalesPriceList);
        if priceList.FindFirst() then
            exit(priceList."Starting Date")

    end;

    local procedure getPriceGroup(priceGroup: Text): Code[20]
    begin
        case priceGroup of
            'RetailPrice':
                exit('R');
            'Wholesale':
                exit('W');
            'W05Calculated':
                exit('W05');
            'W1Calculated':
                exit('W1');
            'W2Calculated':
                exit('W2');
            'W3Calculated':
                exit('W3');
            'W4Calculated':
                exit('W4');
        end;
    end;



    local procedure GenerateQueryContent(): Text
    var
        jObjQuery: JsonObject;
        jObjQueryInner: JsonObject;
        jObjSelect: JsonObject;
        jObjFrom: JsonObject;
        jArrFrom: JsonArray;
        jObjClause: JsonObject;

    begin

        //LOGIC - Build the Select Query
        //NOTE - Build the select object
        jObjSelect.Add('languages', 'EN');
        jObjSelect.Add('options', 'IncludeTotalCount,ExcludeFeatureDefinitions');

        //NOTE - Add features (attributes) needed from Perfion. This is done in buildFeatures()
        jObjSelect.Add('Features', buildFeatures());

        //NOTE - Add to main inner object
        jObjQueryInner.Add('Select', jObjSelect);

        //LOGIC - Build the From Query
        jObjFrom.Add('id', '100');
        jArrFrom.Add(jObjFrom);
        jObjQueryInner.Add('From', jArrFrom);


        //LOGIC - Build the Where Query
        //NOTE - Build each clause with values. This is done in buildClauseArray()
        //NOTE - Add all clauses to main clause object
        jObjClause.Add('Clauses', buildClauseArray());

        //NOTE - Add main clause to the main Where object
        jObjQueryInner.Add('Where', jObjClause);

        //LOGIC - Build the main query object
        jObjQuery.Add('Query', jObjQueryInner);

        exit(Format(jObjQuery));
    end;

    local procedure buildListPriceClause() features: List of [Text]
    begin
        features.Add('RetailPrice');
        features.Add('Wholesale');
        features.Add('W05MaxDiscount');
        features.Add('W1MaxDiscount');
        features.Add('W2MaxDiscount');
        features.Add('W3MaxDiscount');
        features.Add('W4MaxDiscount');
    end;

    local procedure buildListPriceFeatures() features: List of [Text]
    begin
        features.Add('RetailPrice');
        features.Add('Wholesale');
        features.Add('W05Calculated');
        features.Add('W1Calculated');
        features.Add('W2Calculated');
        features.Add('W3Calculated');
        features.Add('W4Calculated');
        features.Add('W05MaxDiscount');
        features.Add('W1MaxDiscount');
        features.Add('W2MaxDiscount');
        features.Add('W3MaxDiscount');
        features.Add('W4MaxDiscount');
    end;

    local procedure buildFeatures(): JsonArray
    var
        features: List of [Text];
        feature: Text;
        jObject: JsonObject;
        jArray: JsonArray;

    begin
        features := buildListPriceFeatures();

        foreach feature in features do begin
            jObject.Add('id', feature);
            jArray.Add(jObject);
            Clear(jObject);
        end;

        exit(jArray);
    end;

    local procedure buildClauseArray(): JsonArray
    var
        features: List of [Text];
        feature: Text;
        jObject: JsonObject;
        jObjectEmpty: JsonObject;
        jArray: JsonArray;

    begin
        features := buildListPriceClause();

        jObject.Add('Clause', buildBrandClause());
        jArray.Add(jObject);
        Clear(jObject);
        jObject.Add('Clause', buildItemTypeClause());
        jArray.Add(jObject);
        Clear(jObject);
        logHandler.enterLog(Process::"Price Sync", 'Setting Clause Date', '', getApiDateFormatText());

        foreach feature in features do begin
            jObject.Add('Clause', buildClauses(feature));
            jObject.Add('Or', jObjectEmpty);
            jArray.Add(jObject);
            Clear(jObject);
        end;

        exit(jArray);
    end;

    local procedure buildBrandClause(): JsonObject
    var
        jObjValue: JsonObject;
    begin

        jObjValue.Add('id', 'brand');
        jObjValue.Add('operator', '=');
        jObjValue.Add('value', 'Normal');
        exit(jObjValue);
    end;

    local procedure buildItemTypeClause(): JsonObject
    var
        jObjValue: JsonObject;
        jObjValueDetail: JsonObject;
        jArrValue: JsonArray;

    begin
        jObjValue.Add('id', 'BCItemType');
        jObjValue.Add('operator', 'IN');
        jArrValue.Add('Assembly');
        jArrValue.Add('Prod. Order');
        jArrValue.Add('Purchase');
        jObjValue.Add('value', jArrValue);
        exit(jObjValue);
    end;

    local procedure buildClauses(priceType: Text): JsonObject
    var
        jObjValue: JsonObject;
        jObjValueDetail: JsonObject;
        jArrValue: JsonArray;
    begin

        //NOTE - example format Perfion expects 2024-05-04 00:00:00"

        jObjValue.Add('id', priceType + '.modifiedDate');
        jObjValue.Add('operator', 'BETWEEN');
        //DEVELOPER - Testing Only
        //jArrValue.Add('2024-05-01 00:00:00');
        //jArrValue.Add('2024-05-05 23:00:00');
        jArrValue.Add(getApiDateFormatText() + ' 00:00:00');
        jArrValue.Add(getApiDateFormatText() + ' 23:00:00');
        jObjValue.Add('value', jArrValue);
        exit(jObjValue);
    end;

    local procedure getApiDateFormatText(): Text
    var
        utcToday: DateTime;
        TypeHelper: Codeunit "Type Helper";
        utcTodayText: Text;
        manualDateText: Text;

    begin
        utcToday := TypeHelper.GetCurrUTCDateTime();
        if useManualDate then
            exit(Format(manualDate, 0, '<Year4>-<Month,2>-<Day,2>'))
        else
            exit(Format(utcToday, 0, '<Year4>-<Month,2>-<Day,2>'));

    end;

    local procedure getLocalDateTime(utc: DateTime): DateTime
    var
        TypeHelper: Codeunit "Type Helper";
    begin
        exit(TypeHelper.ConvertDateTimeFromUTCToTimeZone(utc, 'Central Standard Time'))
    end;

    var
        useManualDate: Boolean;
        manualDate: Date;
        changeCount: Integer;
        logHandler: Codeunit PerfionLogHandler;
        priceLogHandler: Codeunit PerfionPriceLogHandler;
        Process: Enum PerfionProcess;
        apiHandler: Codeunit PerfionApiHandler;

    /*

    Example of post to send to Perfion to get results

{
   "Query": {
      "Select": {
         "languages": "EN",
         "Features": [
            { "id": "RetailPrice" },
            { "id": "Wholesale" },
            { "id": "W05Calculated"},
            { "id": "W1Calculated"},
            { "id": "W2Calculated"},
            { "id": "W3Calculated"},
            { "id": "W4Calculated"}
            ]
        },
        "From": [ 
            { "id": "Product" }
        ],
      "Where": {
         "Clauses": [ 
             { "Clause": { "id": "RetailPrice.modifiedDate", "operator": "BETWEEN", "value": [ "2024-05-03 08:00:00", "2024-05-03 10:00:00" ] }
             },
             { "Or": {} },
             { "Clause": { "id": "Wholesale.modifiedDate", "operator": "BETWEEN", "value": [ "2024-05-03 08:00:00", "2024-05-03 10:00:00" ] }
             },
             { "Or": {} },
             { "Clause": { "id": "W05Calculated.modifiedDate", "operator": "BETWEEN", "value": [ "2024-05-03 08:00:00", "2024-05-03 10:00:00" ] }
             },
             { "Or": {} },
             { "Clause": { "id": "W1Calculated.modifiedDate", "operator": "BETWEEN", "value": [ "2024-05-03 08:00:00", "2024-05-03 10:00:00" ] }
             },
             { "Or": {} },
             { "Clause": { "id": "W2Calculated.modifiedDate", "operator": "BETWEEN", "value": [ "2024-05-03 08:00:00", "2024-05-03 10:00:00" ] }
             },
             { "Or": {} },
             { "Clause": { "id": "W3Calculated.modifiedDate", "operator": "BETWEEN", "value": [ "2024-05-03 08:00:00", "2024-05-03 10:00:00" ] }
             },
             { "Or": {} },
             { "Clause": { "id": "W4Calculated.modifiedDate", "operator": "BETWEEN", "value": [ "2024-05-03 08:00:00", "2024-05-03 10:00:00" ] }
             }
         ]
      }
   }
}


    */
}