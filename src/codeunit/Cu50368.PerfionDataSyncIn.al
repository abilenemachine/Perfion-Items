codeunit 50368 PerfionDataSyncIn
{
    trigger OnRun()
    var
        perfionDataSyncIn: Record PerfionDataSyncIn;
    begin
        perfionDataSyncIn.Get();
        //LOGIC - Update the last sync time
        perfionDataSyncIn.LastSync := CreateDateTime(Today, Time);
        perfionDataSyncIn.Modify();

        //LOGIC - Get the Perfion Token & register variables
        startPerfionRequest();

    end;

    local procedure startPerfionRequest()
    var
        CallResponse: Text;
        Content: Text;
        ErrorList: List of [Text];
        ErrorListMsg: Text;
        ErrorMsg: Text;
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
            logHandler.enterLog(Process::"Data Sync In", 'perfionPostRequest', '', GetLastErrorText());
            exit;
        end;

        if ErrorList.Count > 0 then begin
            foreach ErrorListMsg in ErrorList do begin
                logHandler.enterLog(Process::"Data Sync In", 'perfionPostRequest', '', ErrorListMsg);
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
        itemFeatureValue: JsonToken;
        itemFeatureName: JsonToken;
        featureId: JsonToken;

        modifiedDate: Date;
        recItem: Record Item;
        perfionDataSyncIn: Record PerfionDataSyncIn;
        hasCore: Boolean;
        itemNum: Code[20];
        tempCoreReasource: Code[20];
        tempCoreValue: Decimal;
        tempItemDateModified: DateTime;
        dateLastWeek: Date;

    begin
        changeCount := 0;
        responseObject.ReadFrom(response);
        responseObject.SelectToken('Data', dataToken);
        dataToken.SelectToken('totalCount', totalToken);
        dataToken.SelectToken('Items', itemsToken);

        if useManualDate then
            dateLastWeek := getManualCompareDateLastWeek()
        else
            dateLastWeek := getCompareDateLastWeek();

        logHandler.enterLog(Process::"Data Sync In", 'Setting getDateLastWeek', '', Format(dateLastWeek));

        foreach itemsToken in itemsToken.AsArray() do begin
            itemsToken.SelectToken('Values', valuesToken);
            if valuesToken.AsArray().Count > 0 then begin
                valuesToken.AsArray().Get(0, valueItemToken);
                valueItemToken.SelectToken('value', itemNumToken);

                Clear(itemNum);
                itemNum := itemNumToken.AsValue().AsCode();

                if checkItem(itemNum) then begin

                    hasCore := false;
                    Clear(tempCoreReasource);
                    Clear(tempCoreValue);
                    //NOTE - Loop through all attributes. The first is the item number (featureId:100)

                    foreach valuesToken in valuesToken.AsArray() do begin
                        valuesToken.SelectToken('featureId', featureId);
                        if featureId.AsValue().AsInteger() <> 100 then begin

                            valuesToken.SelectToken('modifiedDate', itemDateModified);
                            modifiedDate := DT2Date(itemDateModified.AsValue().AsDateTime());

                            //DEVELOPER - Testing Only
                            //dateLastWeek := DMY2Date(9, 5, 2024);

                            valuesToken.SelectToken('value', itemFeatureValue);
                            valuesToken.SelectToken('featureName', itemFeatureName);
                            valuesToken.SelectToken('modifiedDate', itemDateModified);

                            if modifiedDate > dateLastWeek then begin
                                if itemFeatureName.AsValue().AsText() = 'PartNameProductDescription' then
                                    updateItemDescription(itemNum, itemFeatureValue.AsValue().AsText(), itemDateModified.AsValue().AsDateTime())
                                else if itemFeatureName.AsValue().AsText() = 'SAGroup2' then
                                    updateItemCategory(itemNum, itemFeatureValue.AsValue().AsCode(), itemDateModified.AsValue().AsDateTime())
                                else if itemFeatureName.AsValue().AsText() = 'CoreResourceName' then
                                    tempCoreReasource := itemFeatureValue.AsValue().AsCode()
                                else if itemFeatureName.AsValue().AsText() = 'Core' then begin
                                    hasCore := true;
                                    tempCoreValue := itemFeatureValue.AsValue().AsDecimal();
                                    tempItemDateModified := itemDateModified.AsValue().AsDateTime();
                                end;
                            end
                            else begin
                                if itemFeatureName.AsValue().AsText() = 'CoreResourceName' then
                                    tempCoreReasource := itemFeatureValue.AsValue().AsCode()
                                else if itemFeatureName.AsValue().AsText() = 'Core' then begin
                                    hasCore := true;
                                    tempCoreValue := itemFeatureValue.AsValue().AsDecimal();
                                    tempItemDateModified := itemDateModified.AsValue().AsDateTime();
                                end;

                            end;
                        end;
                    end;
                    if hasCore then
                        updateCoreData(itemNum, tempCoreReasource, tempCoreValue, tempItemDateModified)
                    else
                        updateCoreData(itemNum, '', 0, tempItemDateModified);

                end;

            end;
            perfionDataSyncIn.Get();
            perfionDataSyncIn.Processed := changeCount;
            perfionDataSyncIn.TotalCount := totalToken.AsValue().AsInteger();
            perfionDataSyncIn.Modify();

        end;
    end;

    local procedure checkItem(itemNo: Code[20]): Boolean
    var
        recItem: Record Item;

    begin
        if Text.StrLen(itemNo) > 20 then begin
            logHandler.enterLog(Process::"Data Sync In", 'checkItem', itemNo, 'Item Num too long');
            exit(false);
        end;
        recItem.Reset();

        if not recItem.Get(itemNo) then begin
            logHandler.enterLog(Process::"Data Sync In", 'checkItem', itemNo, 'Item not in BC');
            exit(false);
        end
        else if recItem.Blocked then begin
            logHandler.enterLog(Process::"Data Sync In", 'checkItem', itemNo, 'Item Blocked in BC');
            exit(false);
        end
        else
            exit(true);
    end;


    local procedure updateItemDescription(itemNo: Code[20]; newDescription: Text; modified: DateTime)
    var
        oldDescription: Text;
        recItem: Record Item;

    begin
        recItem.Reset();
        recItem.SetFilter("No.", itemNo);
        if recItem.FindFirst() then begin
            if recItem.Description <> newDescription then begin
                oldDescription := recItem.Description;
                recItem.Description := newDescription;
                if recItem.Modify() then begin
                    dataLogHandler.LogItemUpdate(itemNo, newDescription, oldDescription, Enum::PerfionValueType::Description, getLocalDateTime(modified));
                    changeCount += 1;
                end
                else
                    logHandler.enterLog(Process::"Data Sync In", 'Error Updating Description', itemNo, GetLastErrorText());
            end;
        end;
    end;

    local procedure updateItemCategory(itemNo: Code[20]; newCategory: Code[20]; modified: DateTime)
    var
        oldCategory: Code[20];
        recItem: Record Item;

    begin
        recItem.Reset();
        recItem.SetFilter("No.", itemNo);
        if recItem.FindFirst() then begin
            if recItem."Item Category Code" <> newCategory then begin
                oldCategory := recItem."Item Category Code";
                recItem."Item Category Code" := newCategory;
                if recItem.Modify() then begin
                    dataLogHandler.LogItemUpdate(itemNo, newCategory, oldCategory, Enum::PerfionValueType::ItemCategory, getLocalDateTime(modified));
                    changeCount += 1;
                end
                else
                    logHandler.enterLog(Process::"Data Sync In", 'Error Updating Item Category', itemNo, GetLastErrorText());
            end;
        end;
    end;

    local procedure updateCoreData(itemNo: Code[20]; newCoreResource: Code[20]; newCoreValue: Decimal; modified: DateTime)
    var
        oldCoreValue: Decimal;
        recItem: Record Item;
        oldCoreResource: Code[20];
        magentoSync: Codeunit MagentoDataSync;
        needSync: Boolean;

    begin
        needSync := false;
        recItem.Reset();
        recItem.SetFilter("No.", itemNo);
        if recItem.FindFirst() then begin
            if recItem."Core Sales Value" <> newCoreValue then begin
                oldCoreValue := recItem."Core Sales Value";
                recItem."Core Sales Value" := newCoreValue;

                if recItem.Modify() then begin
                    dataLogHandler.LogItemUpdate(itemNo, Format(newCoreValue), Format(oldCoreValue), Enum::PerfionValueType::CoreValue, getLocalDateTime(modified));
                    changeCount += 1;
                    needSync := true;
                end
                else
                    logHandler.enterLog(Process::"Data Sync In", 'Error Updating Core Value', itemNo, GetLastErrorText());
            end;

            if recItem."Core Resource Name" <> newCoreResource then begin
                oldCoreResource := recItem."Core Resource Name";
                recItem."Core Resource Name" := newCoreResource;

                if recItem.Modify() then begin
                    dataLogHandler.LogItemUpdate(itemNo, Format(newCoreResource), Format(oldCoreResource), Enum::PerfionValueType::CoreResource, getLocalDateTime(modified));
                    changeCount += 1;
                    needSync := true;
                end
                else
                    logHandler.enterLog(Process::"Data Sync In", 'Error Updating Core Resource', itemNo, GetLastErrorText());
            end;

            if needSync then
                magentoSync.sendCoreData(itemNo);
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

    local procedure buildListFeatureTypes() features: List of [Text]
    begin
        features.Add('PartNameProductDescription');
        features.Add('SAGroup2');
        features.Add('Core');
        features.Add('CoreResourceName');
    end;

    local procedure buildFeatures(): JsonArray
    var
        features: List of [Text];
        feature: Text;
        jObject: JsonObject;
        jArray: JsonArray;

    begin
        features := buildListFeatureTypes();

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
        features := buildListFeatureTypes();

        jObject.Add('Clause', buildBrandClause());
        jArray.Add(jObject);
        Clear(jObject);
        jObject.Add('Clause', buildItemTypeClause());
        jArray.Add(jObject);
        Clear(jObject);
        jObject.Add('Clause', buildItemModifiedClause());
        jObject.Add('Or', jObjectEmpty);
        jArray.Add(jObject);
        Clear(jObject);

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

    local procedure buildItemModifiedClause(): JsonObject
    var
        jObjValue, jObjValueDetail : JsonObject;
        jArrValue: JsonArray;
        utcToday: DateTime;
        TypeHelper: Codeunit "Type Helper";
        utcTodayText, utcLastWeekText : Text;
        manualDateText, manualLastWeekText : Text;

    begin
        utcToday := TypeHelper.GetCurrUTCDateTime();

        utcTodayText := Format(utcToday, 0, '<Year4>-<Month,2>-<Day,2>');
        utcLastWeekText := Format(getDateLastWeek(), 0, '<Year4>-<Month,2>-<Day,2>');

        //NOTE - example format Perfion expects 2024-05-04 00:00:00"

        jObjValue.Add('id', 'modifiedDate');
        jObjValue.Add('operator', 'BETWEEN');
        //DEVELOPER - Testing Only
        //jArrValue.Add('2024-05-10 00:00:00');
        //jArrValue.Add('2024-05-10 23:00:00');
        if useManualDate then begin
            manualDateText := Format(manualDate, 0, '<Year4>-<Month,2>-<Day,2>');
            manualLastWeekText := Format(getManualDateLastWeek(), 0, '<Year4>-<Month,2>-<Day,2>');
            jArrValue.Add(manualLastWeekText + ' 00:00:00');
            jArrValue.Add(manualDateText + ' 23:00:00');
            logHandler.enterLog(Process::"Data Sync In", 'Setting Clause Date Start', '', manualLastWeekText);
            logHandler.enterLog(Process::"Data Sync In", 'Setting Clause Date End', '', manualDateText);
        end
        else begin
            jArrValue.Add(utcLastWeekText + ' 00:00:00');
            jArrValue.Add(utcTodayText + ' 23:00:00');
            logHandler.enterLog(Process::"Data Sync In", 'Setting Clause Date Start', '', utcLastWeekText);
            logHandler.enterLog(Process::"Data Sync In", 'Setting Clause Date End', '', utcTodayText);
        end;

        jObjValue.Add('value', jArrValue);

        exit(jObjValue);
    end;

    local procedure buildClauses(featureType: Text): JsonObject
    var
        jObjValue, jObjValueDetail : JsonObject;
        jArrValue: JsonArray;
        utcToday: DateTime;
        TypeHelper: Codeunit "Type Helper";
        utcTodayText, utcLastWeekText : Text;
        manualDateText, manualLastWeekText : Text;

    begin
        utcToday := TypeHelper.GetCurrUTCDateTime();

        utcTodayText := Format(utcToday, 0, '<Year4>-<Month,2>-<Day,2>');
        utcLastWeekText := Format(getDateLastWeek(), 0, '<Year4>-<Month,2>-<Day,2>');

        //NOTE - example format Perfion expects 2024-05-04 00:00:00"

        jObjValue.Add('id', featureType + '.modifiedDate');
        jObjValue.Add('operator', 'BETWEEN');
        //DEVELOPER - Testing Only
        //jArrValue.Add('2024-05-10 00:00:00');
        //jArrValue.Add('2024-05-10 23:00:00');
        if useManualDate then begin
            manualDateText := Format(manualDate, 0, '<Year4>-<Month,2>-<Day,2>');
            manualLastWeekText := Format(getManualDateLastWeek(), 0, '<Year4>-<Month,2>-<Day,2>');
            jArrValue.Add(manualLastWeekText + ' 00:00:00');
            jArrValue.Add(manualDateText + ' 23:00:00');
        end
        else begin
            jArrValue.Add(utcLastWeekText + ' 00:00:00');
            jArrValue.Add(utcTodayText + ' 23:00:00');
        end;
        jObjValue.Add('value', jArrValue);

        exit(jObjValue);
    end;

    local procedure getLocalDateTime(utc: DateTime): DateTime
    var
        TypeHelper: Codeunit "Type Helper";
    begin
        exit(TypeHelper.ConvertDateTimeFromUTCToTimeZone(utc, 'Central Standard Time'))
    end;

    local procedure getDateLastWeek(): Date
    begin

        exit(CalcDate('<-7D>', Today))
    end;

    local procedure getCompareDateLastWeek(): Date
    begin

        exit(CalcDate('<-8D>', Today))
    end;

    local procedure getManualDateLastWeek(): Date
    begin
        exit(CalcDate('<-7D>', manualDate))
    end;

    local procedure getManualCompareDateLastWeek(): Date
    begin
        exit(CalcDate('<-8D>', manualDate))
    end;


    var
        useManualDate: Boolean;
        manualDate: Date;
        logHandler: Codeunit PerfionLogHandler;
        dataLogHandler: Codeunit PerfionDataInLogHandler;
        changeCount: Integer;
        Process: Enum PerfionProcess;
        apiHandler: Codeunit PerfionApiHandler;

    /*

    Example of post to send to Perfion to get results

{
   "Query": 
   {
      "Select": 
      {
         "languages": "EN",
         "options": "IncludeTotalCount,ExcludeFeatureDefinitions",
         "Features": [
            { "id": "PartNameProductDescription" },
            { "id": "SAGroup2" },
            { "id": "CoreResourceName"},
            { "id": "Core"}
        ]
      },
        "From": [ 
            { "id": "100" }
        ],
      "Where": {
         "Clauses": [ 
             { "Clause": { "id": "brand", "operator": "=", "value": "Normal" } },
             { "Clause": { "id": "BCItemType", "operator": "IN", "value": [ "Assembly", "Prod. Order", "Purchase" ] } },
             { "Clause": { "id": "modifiedDate", "operator": "BETWEEN", "value": [ "2024-05-10 00:00:00", "2024-05-10 23:00:00" ] }
             },
             { "Or": {} },
             { "Clause": { "id": "PartNameProductDescription.modifiedDate", "operator": "BETWEEN", "value": [ "2024-05-10 00:00:00", "2024-05-10 23:00:00" ] }
             },
            { "Or": {} },
             { "Clause": { "id": "SAGroup2.modifiedDate", "operator": "BETWEEN", "value": [ "2024-05-10 00:00:00", "2024-05-10 23:00:00" ] }
             },
            { "Or": {} },
             { "Clause": { "id": "CoreResourceName.modifiedDate", "operator": "BETWEEN", "value": [ "2024-05-10 00:00:00", "2024-05-10 23:00:00" ] }
             },
            { "Or": {} },
             { "Clause": { "id": "Core.modifiedDate", "operator": "BETWEEN", "value": [ "2024-05-10 00:00:00", "2024-05-10 23:00:00" ] }
             }
         ]
      }
   }
}


    */
}