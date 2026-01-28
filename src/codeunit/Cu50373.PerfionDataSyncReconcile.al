codeunit 50373 PerfionDataSyncReconcile
{
    trigger OnRun()

    begin

        currDateTime := CurrentDateTime;

        if perfionDataReconcile.Get() then begin

            //LOGIC - Get the Perfion Token & register variables
            startPerfionRequest();
        end;


    end;

    local procedure startPerfionRequest()
    begin
        getPerfionItemCat();

    end;


    local procedure getPerfionItemCat()
    var
        CallResponse: Text;
        Content: Text;
        ErrorList: List of [Text];
        ErrorListMsg: Text;
        ErrorMsg: Text;

    begin
        Content := genQueryItemCat();
        if not apiHandler.perfionPostRequest(CallResponse, ErrorList, Content) then begin
            logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::Reconcile, 'startPerfionRequest', Enum::ErrorType::Catch, GetLastErrorText());
            exit;
        end;

        if ErrorList.Count > 0 then begin
            foreach ErrorListMsg in ErrorList do begin
                logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Price Sync", 'startPerfionRequest', Enum::ErrorType::Crash, ErrorListMsg);
            end;
            exit;
        end;

        changeCount := 0;
        totalCount := 0;
        processPerfionCatChild(CallResponse)
    end;

    local procedure processPerfionCatChild(response: Text)
    var
        responseObject: JsonObject;
        dataToken: JsonToken;
        totalToken: JsonToken;
        itemsToken: JsonToken;
        itemFeatureName: JsonToken;
        featureIdToken, mainIdToken : JsonToken;
        valuesToken: JsonToken;
        descriptionToken: JsonToken;
        codeToken: JsonToken;
        idToken, parentIdToken : JsonToken;
        catParent: Dictionary of [Integer, Text];
        catId, catParentId : Integer;
        catDescription: Text[100];
        catCode: Code[20];
        catParentCat: Code[20];

    begin

        responseObject.ReadFrom(response);
        responseObject.SelectToken('Data', dataToken);
        dataToken.SelectToken('Items', itemsToken);

        foreach itemsToken in itemsToken.AsArray() do begin
            itemsToken.SelectToken('Values', valuesToken);
            itemsToken.SelectToken('featureId', featureIdToken);
            itemsToken.SelectToken('id', mainIdToken);


            if featureIdToken.AsValue().AsInteger() = 327 then begin

                Clear(catCode);
                Clear(catDescription);
                Clear(catId);
                Clear(catParentId);
                Clear(catParentCat);

                foreach valuesToken in valuesToken.AsArray() do begin

                    valuesToken.SelectToken('featureName', itemFeatureName);

                    if itemFeatureName.AsValue().AsText() = 'Value' then begin
                        valuesToken.SelectToken('value', codeToken);
                        catCode := codeToken.AsValue().AsCode();
                    end
                    else if itemFeatureName.AsValue().AsText() = 'Category' then begin
                        valuesToken.SelectToken('value', descriptionToken);
                        catDescription := descriptionToken.AsValue().AsText();
                        valuesToken.SelectToken('id', idToken);
                        catId := idToken.AsValue().AsInteger();
                        valuesToken.SelectToken('parentID', parentIdToken);
                        catParentId := parentIdToken.AsValue().AsInteger();
                        catParentCat := DelStr(catCode, 4, 3);
                    end
                end;

                recItemCatTemp.Init();
                recItemCatTemp.Code := catCode;
                recItemCatTemp."Parent Category" := catParentCat;
                recItemCatTemp.Description := catDescription;
                recItemCatTemp."Has Children" := false;
                recItemCatTemp.PerfionId := catId;
                recItemCatTemp.PerfionParentId := catParentId;
                if recItemCatTemp.Insert() then
                    totalCount += 1;

                if not recItemCatTemp.Get(catParentCat) then begin
                    recItemCatTemp.Init();
                    recItemCatTemp.Code := catParentCat;
                    recItemCatTemp."Has Children" := true;
                    recItemCatTemp.PerfionId := catParentId;
                    if recItemCatTemp.Insert() then
                        totalCount += 1;
                end;
            end;
        end;

        processPerfionCatParent(response);
    end;

    local procedure processPerfionCatParent(response: Text)
    var
        responseObject: JsonObject;
        dataToken: JsonToken;
        totalToken: JsonToken;
        itemsToken: JsonToken;
        itemFeatureValue: JsonToken;
        itemFeatureName: JsonToken;
        featureIdToken: JsonToken;
        brandToken: JsonToken;
        valuesToken: JsonToken;
        valueCodeToken: JsonToken;
        valueNameToken: JsonToken;
        descriptionToken: JsonToken;
        codeToken: JsonToken;
        idToken, parentIdToken : JsonToken;
        catParent: Dictionary of [Integer, Text];
        catParentId: Integer;
        catId: Integer;
        catDescription: Text[100];
        catCode: Code[20];
        catParentCat: Code[20];

    begin
        changeCount := 0;
        responseObject.ReadFrom(response);
        responseObject.SelectToken('Data', dataToken);
        dataToken.SelectToken('totalCount', totalToken);
        dataToken.SelectToken('Items', itemsToken);

        foreach itemsToken in itemsToken.AsArray() do begin
            itemsToken.SelectToken('Values', valuesToken);
            itemsToken.SelectToken('featureId', featureIdToken);
            itemsToken.SelectToken('brand', brandToken);
            itemsToken.SelectToken('id', idToken);
            catId := idToken.AsValue().AsInteger();

            if (featureIdToken.AsValue().AsInteger() = 102) and (brandToken.AsValue().AsText() = 'Virtual') then begin
                if (catId <> 335) and (catId <> 336) then begin

                    valuesToken.AsArray().Get(0, valueNameToken);
                    valueNameToken.SelectToken('value', descriptionToken);
                    catDescription := descriptionToken.AsValue().AsText();

                    recItemCatTemp.Reset();
                    recItemCatTemp.SetRange(PerfionId, catId);
                    if recItemCatTemp.FindFirst() then begin
                        recItemCatTemp.Description := catDescription;
                        recItemCatTemp.Modify();
                    end;
                end;
            end;
        end;

        reconcileItemCategory();
        /*
        if recItemCatTemp.FindSet() then begin
            repeat
                logHandler.enterLog(Process::"Reconcile", recItemCatTemp.Description, recItemCatTemp.Code, recItemCatTemp."Parent Category");
            until recItemCatTemp.Next() = 0;
        end;
        */
    end;

    local procedure reconcileItemCategory()
    var
        recItemCat: Record "Item Category";
        perfionDataReconcile: Record PerfionDataReconcile;
        itemsMatched: List of [Code[20]];
    begin
        recItemCatTemp.Reset();
        if recItemCatTemp.FindSet() then begin
            repeat
                recItemCat.SetRange("Code", recItemCatTemp."Code");
                if recItemCat.FindFirst() then begin
                    if recItemCat.Description <> recItemCatTemp.Description then begin
                        dataLogHandler.LogCatUpdate(recItemCat.Code, recItemCat.Description, recItemCatTemp.Description, ValueType::Description, ReconcileType::Change);
                        recItemCat.Description := recItemCatTemp.Description;
                        changeCount += 1;
                    end;
                    if recItemCat."Parent Category" <> recItemCatTemp."Parent Category" then begin
                        dataLogHandler.LogCatUpdate(recItemCat.Code, recItemCat."Parent Category", recItemCatTemp."Parent Category", ValueType::ParentCategory, ReconcileType::Change);
                        recItemCat."Parent Category" := recItemCatTemp."Parent Category";
                        changeCount += 1;
                    end;
                    if recItemCat.PerfionId <> recItemCatTemp.PerfionId then begin
                        dataLogHandler.LogCatUpdate(recItemCat.Code, Format(recItemCat.PerfionId), Format(recItemCatTemp.PerfionId), ValueType::PerfionId, ReconcileType::Change);
                        recItemCat.PerfionId := recItemCatTemp.PerfionId;
                        changeCount += 1;
                    end;
                    if recItemCat.PerfionParentId <> recItemCatTemp.PerfionParentId then begin
                        dataLogHandler.LogCatUpdate(recItemCat.Code, Format(recItemCat.PerfionParentId), Format(recItemCatTemp.PerfionParentId), ValueType::PerfionParentId, ReconcileType::Change);
                        recItemCat.PerfionParentId := recItemCatTemp.PerfionParentId;
                        changeCount += 1;
                    end;
                    recItemCat.Modify();
                end else begin
                    recItemCat.Init();
                    recItemCat.TransferFields(recItemCatTemp);
                    if recItemCat.Insert() then begin
                        dataLogHandler.LogCatUpdate(recItemCat.Code, '', '', ValueType::None, ReconcileType::Addition);
                        changeCount += 1;
                    end;
                end;
            until recItemCatTemp.Next() = 0;
        end;

        recItemCat.Reset();
        recItemCatTemp.Reset();
        if recItemCat.FindSet() then begin
            repeat
                recItemCatTemp.SetRange("Code", recItemCat."Code");
                if not recItemCatTemp.FindFirst() then begin
                    Clear(itemsMatched);
                    itemsMatched := getItemsByCat(recItemCat.Code);
                    if itemsMatched.Count = 0 then begin
                        if recItemCat.Delete() then begin
                            dataLogHandler.LogCatUpdate(recItemCat.Code, '', '', ValueType::None, ReconcileType::Removal);
                            changeCount += 1;
                        end;
                    end
                    else
                        emailUsers(recItemCat.Code, itemsMatched);

                end;
            until recItemCat.Next() = 0;
        end;

        perfionDataReconcile.Processed := changeCount;
        perfionDataReconcile.TotalCount := totalCount;
        //LOGIC - Update the last sync time
        perfionDataReconcile.LastSync := currDateTime;
        perfionDataReconcile.Modify();
    end;

    local procedure getItemsByCat(catCode: Code[20]) Values: List of [Code[20]]
    var
        recItem: Record Item;
    begin
        recItem.Reset();
        recItem.SetFilter("Item Category Code", catCode);
        if recItem.FindSet() then begin
            repeat
                Values.Add(recItem."No.");
            until recItem.Next() = 0;
        end;
    end;

    procedure convertListToEmail(items: List of [Code[20]]): Text
    var
        lineBreakString: Text;
        item: Code[20];

    begin
        foreach item in items do begin
            lineBreakString += format(item) + '<br>';
        end;
        if lineBreakString <> '' then
            lineBreakString := copystr(lineBreakString, 1, strlen(lineBreakString) - 2);
        exit(lineBreakString);
    end;

    local procedure emailUsers(catCode: Code[20]; items: List of [Code[20]])
    var
        EmailMessage: Codeunit "Email Message";
        Email: Codeunit Email;
        Recipients: List of [Text];
        Subject: Text;
        Body: Text;
        Title: Label 'Item Category Deletion %1';
        Msg: Label 'Item Category Deletion<br><br>The Item Category <font color="red"><strong>%1</strong></font> has the following items associated to it<br><br>%2';
        itemNos: Text;

    begin
        itemNos := convertListToEmail(items);

        Recipients.Add('lfritts@abilenemachine.com');
        Recipients.Add('wmarkley@abilenemachine.com');
        Recipients.Add('kjustice@abilenemachine.com');
        dataLogHandler.LogCatUpdate(catCode, '', '', ValueType::None, ReconcileType::EmailSent);

        Subject := StrSubstNo(Title, catCode);
        Body := StrSubstNo(Msg, catCode, DelChr(itemNos, '>', '<b'));
        EmailMessage.Create(Recipients, Subject, Body, true);
        Email.Send(EmailMessage, Enum::"Email Scenario"::Notification);
    end;


    local procedure genQueryItemCat(): Text
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

        jObjSelect.Add('Features', buildItemCatFeatures());

        //NOTE - Add to main inner object
        jObjQueryInner.Add('Select', jObjSelect);

        //LOGIC - Build the From Query
        jObjFrom.Add('id', 'SAGroup2');
        jArrFrom.Add(jObjFrom);
        Clear(jObjFrom);
        jObjFrom.Add('id', 'Category');
        jArrFrom.Add(jObjFrom);
        jObjQueryInner.Add('From', jArrFrom);

        /*
        jObjClause.Add('Clauses', buildClauseArray());
        jObjQueryInner.Add('Where', jObjClause);
        */

        //LOGIC - Build the main query object
        jObjQuery.Add('Query', jObjQueryInner);

        exit(Format(jObjQuery));
    end;

    local procedure buildItemCatFeatures(): JsonArray
    var
        jObject: JsonObject;
        jArray: JsonArray;
    begin
        jObject.Add('id', 'SAGroup2');
        jArray.Add(jObject);
        Clear(jObject);
        jObject.Add('id', 'Category');
        jArray.Add(jObject);

        exit(jArray);
    end;

    local procedure buildClauseArray(): JsonArray
    var
        jObject: JsonObject;
        jArray: JsonArray;
    begin
        jObject.Add('Clause', buildBrandClause());
        jArray.Add(jObject);
        exit(jArray);
    end;

    local procedure buildBrandClause(): JsonObject
    var
        jObjValue: JsonObject;
    begin

        jObjValue.Add('id', 'brand');
        jObjValue.Add('operator', '=');
        jObjValue.Add('value', 'Virtual');
        exit(jObjValue);
    end;


    var
        dataLogHandler: Codeunit PerfionReconcileLogHandler;
        changeCount: Integer;
        totalCount: Integer;
        ReconcileType: Enum PerfionReconcileType;
        ValueType: Enum PerfionValueType;
        apiHandler: Codeunit PerfionApiHandler;
        recItemCatTemp: Record "Item Category" temporary;
        perfionDataReconcile: Record PerfionDataReconcile;
        currDateTime: DateTime;
        logManager: Codeunit LogManager;

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
            { "id": "Category" },
            { "id": "SAGroup2" }
        ]
      },
        "From": [ 
             { "id": "Category" },
            { "id": "SAGroup2" }
        ]
   }
}


    */
}