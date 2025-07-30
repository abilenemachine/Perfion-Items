codeunit 50368 PerfionDataSyncIn
{
    trigger OnRun()

    var
        perfionSyncOut: Record PerfionDataSyncOut;

    begin
        //NOTE - currDateTime is always in EST Time because it is based on my time zone
        currDateTime := CurrentDateTime;

        perfionSyncOut.Get();
        lastPerfionSync := perfionSyncOut.LastSync;

        if perfionConfig.Get() then begin
            //LOGIC - For the last sync of the day, run a full sync with no date filters
            if (CheckTime()) or (perfionConfig.fullSync) then
                fullSync := true
            else
                fullSync := false;

            if perfionDataSyncIn.Get() then begin
                changeCount := 0;

                //LOGIC - Get the Perfion Token & register variables
                startPerfionRequest();
            end;
        end;
    end;

    procedure CheckTime(): Boolean
    var
        MyTime: Time;
        CurrentTime: Time;
        IsLater: Boolean;
    begin
        // 1. Define the target time using a TIME LITERAL.
        MyTime := 180000T; // 6:00:00 PM (24-hour format)
        CurrentTime := Time();
        IsLater := CurrentTime >= MyTime;

        if IsLater then
            logManager.logInfo(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'CheckTime true', Format(CurrentTime) + ' - ' + Format(MyTime))
        else
            logManager.logInfo(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'CheckTime false', Format(CurrentTime) + ' - ' + Format(MyTime));


        exit(IsLater); // Return the result
    end;

    local procedure startPerfionRequest()
    var
        CallResponse: Text;
        Content: Text;
        ErrorList: List of [Text];
        ErrorListMsg: Text;
        ErrorMsg: Text;

    begin


        Content := GenerateQueryContent();

        if not apiHandler.perfionPostRequest(CallResponse, ErrorList, Content) then begin
            logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'startPerfionRequest', Enum::ErrorType::Catch, GetLastErrorText());
            exit;
        end;

        if ErrorList.Count > 0 then begin
            foreach ErrorListMsg in ErrorList do begin
                logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'startPerfionRequest', Enum::ErrorType::Crash, ErrorListMsg);
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
        itemDateModified, itemDateCreated : JsonToken;
        itemFeatureValue: JsonToken;
        itemFeatureName: JsonToken;
        featureId: JsonToken;

        modifiedDate: Date;
        createdDate: Date;
        recItem: Record Item;
        hasCore, hasPicInstructions, hasApplications, hasUserNotes : Boolean;
        itemNum: Code[20];
        tempCoreResource: Code[20];
        tempCoreValue: Decimal;
        tempItemDateModified: DateTime;
        tempApplications: Text[2048];
        tempUserNotes: Text[2048];
        modifiedDateTime, createdDateTime : DateTime;
        tempPicInstructions: Text[400];

    begin

        responseObject.ReadFrom(response);
        responseObject.SelectToken('Data', dataToken);
        dataToken.SelectToken('totalCount', totalToken);

        if totalToken.AsValue().AsInteger() = 0 then begin
            perfionDataSyncIn.Processed := changeCount;
            perfionDataSyncIn.TotalCount := totalToken.AsValue().AsInteger();
            //LOGIC - Update the last sync time
            perfionDataSyncIn.LastSync := currDateTime;
            perfionDataSyncIn.Modify();
        end;

        dataToken.SelectToken('Items', itemsToken);

        foreach itemsToken in itemsToken.AsArray() do begin
            itemsToken.SelectToken('Values', valuesToken);
            if valuesToken.AsArray().Count > 0 then begin
                valuesToken.AsArray().Get(0, valueItemToken);
                valueItemToken.SelectToken('value', itemNumToken);

                Clear(itemNum);
                itemNum := CopyStr(itemNumToken.AsValue().AsCode(), 1, MaxStrLen(itemNum));

                if checkItem(itemNum) then begin
                    currentItem := itemNum;

                    hasCore := false;
                    hasPicInstructions := false;
                    hasUserNotes := false;
                    hasApplications := false;
                    Clear(tempCoreResource);
                    Clear(tempCoreValue);
                    Clear(tempPicInstructions);
                    Clear(tempApplications);
                    Clear(tempUserNotes);

                    Clear(createdDate);
                    Clear(createdDateTime);
                    itemsToken.SelectToken('createdDate', itemDateCreated);
                    createdDate := DT2Date(itemDateCreated.AsValue().AsDateTime());
                    createdDateTime := itemDateCreated.AsValue().AsDateTime();

                    //NOTE - Loop through all attributes. The first is the item number (featureId:100)

                    foreach valuesToken in valuesToken.AsArray() do begin
                        valuesToken.SelectToken('featureId', featureId);
                        if featureId.AsValue().AsInteger() <> 100 then begin

                            Clear(modifiedDate);

                            valuesToken.SelectToken('modifiedDate', itemDateModified);
                            modifiedDate := DT2Date(itemDateModified.AsValue().AsDateTime());

                            //DEVELOPER - Testing Only
                            //dateLastWeek := DMY2Date(9, 5, 2024);

                            valuesToken.SelectToken('value', itemFeatureValue);
                            valuesToken.SelectToken('featureName', itemFeatureName);
                            modifiedDateTime := itemDateModified.AsValue().AsDateTime();

                            updatePerfionCreatedOn(itemNum, createdDateTime, modifiedDateTime);

                            if itemFeatureName.AsValue().AsText() = 'PartNameProductDescription' then
                                updateItemDescription(itemNum, itemFeatureValue.AsValue().AsText(), modifiedDateTime)
                            else if itemFeatureName.AsValue().AsText() = 'SAGroup2' then
                                updateItemCategory(itemNum, itemFeatureValue.AsValue().AsCode(), modifiedDateTime)
                            else if itemFeatureName.AsValue().AsText() = 'PerfionPictureStatus' then
                                updateItemPicture(itemNum, itemFeatureValue.AsValue().AsText(), modifiedDateTime)
                            else if itemFeatureName.AsValue().AsText() = 'Visibility' then
                                updateItemVisibility(itemNum, itemFeatureValue.AsValue().AsInteger(), modifiedDateTime)
                            else if itemFeatureName.AsValue().AsText() = 'P1SalesManagerEnrichStatus' then
                                updateEnrichStatus(itemNum, itemFeatureValue.AsValue().AsText(), modifiedDateTime)
                            else if itemFeatureName.AsValue().AsText() = 'USERNotes' then
                                updatePerfionUserNotes(itemNum, itemFeatureValue.AsValue().AsText(), modifiedDateTime)
                            else if itemFeatureName.AsValue().AsText() = 'BCUserNotes' then begin
                                hasUserNotes := true;
                                tempUserNotes := itemFeatureValue.AsValue().AsText();
                                tempItemDateModified := modifiedDateTime;
                            end
                            else if itemFeatureName.AsValue().AsText() = 'BCApplications' then begin
                                hasApplications := true;
                                tempApplications := itemFeatureValue.AsValue().AsText();
                                tempItemDateModified := modifiedDateTime;
                            end
                            else if itemFeatureName.AsValue().AsText() = 'PhotographyPickerInstructions' then begin
                                hasPicInstructions := true;
                                tempPicInstructions := itemFeatureValue.AsValue().AsText();
                                tempItemDateModified := modifiedDateTime;
                            end
                            else if itemFeatureName.AsValue().AsText() = 'CoreResourceName' then
                                tempCoreResource := itemFeatureValue.AsValue().AsCode()
                            else if itemFeatureName.AsValue().AsText() = 'Core' then begin
                                hasCore := true;
                                tempCoreValue := itemFeatureValue.AsValue().AsDecimal();
                                tempItemDateModified := modifiedDateTime;
                            end;

                        end;
                    end;
                    if hasCore then
                        updateCoreData(itemNum, tempCoreResource, tempCoreValue, tempItemDateModified)
                    else
                        updateCoreData(itemNum, '', 0, tempItemDateModified);

                    if hasPicInstructions then
                        updatePictureInstructions(itemNum, tempPicInstructions, tempItemDateModified)
                    else
                        updatePictureInstructions(itemNum, '', tempItemDateModified);

                    if hasUserNotes then
                        updateItemUserNotes(itemNum, tempUserNotes, modifiedDateTime)
                    else
                        if not WasFieldModifiedAfterSync(itemNum, 'User Notes', lastPerfionSync) then
                            updateItemUserNotes(itemNum, '', modifiedDateTime);

                    if hasApplications then
                        updateItemApplications(itemNum, tempApplications, modifiedDateTime)
                    else
                        if not WasFieldModifiedAfterSync(itemNum, 'Application', lastPerfionSync) then
                            updateItemApplications(itemNum, '', modifiedDateTime);
                end;

            end;

            perfionDataSyncIn.Processed := changeCount;
            perfionDataSyncIn.TotalCount := totalToken.AsValue().AsInteger();
            //LOGIC - Update the last sync time
            perfionDataSyncIn.LastSync := currDateTime;
            perfionDataSyncIn.Modify();

            perfionConfig.fullSync := false;
            perfionConfig.Modify();

        end;
    end;

    local procedure checkItem(itemNo: Code[20]): Boolean
    var
        recItem: Record Item;

    begin
        if Text.StrLen(itemNo) > 20 then begin
            logManager.logInfo(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'checkItem', itemNo, 'Item No too long');
            exit(false);
        end;
        recItem.Reset();

        if not recItem.Get(itemNo) then begin
            logManager.logInfo(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'checkItem', itemNo, 'Item not in BC');
            exit(false);
        end
        else if recItem.Blocked then begin
            logManager.logInfo(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'checkItem', itemNo, 'Item blocked in BC');
            exit(false);
        end
        else
            exit(true);
    end;

    local procedure updatePerfionCreatedOn(itemNo: Code[20]; newCreatedOn: DateTime; modified: DateTime)
    var
        oldCreatedOn: DateTime;
        recItem: Record Item;

    begin
        recItem.Reset();
        recItem.SetFilter("No.", itemNo);
        if recItem.FindFirst() then begin
            if recItem.PerfionCreatedOn < newCreatedOn then begin
                oldCreatedOn := recItem.PerfionCreatedOn;
                recItem.PerfionCreatedOn := newCreatedOn;
                if recItem.Modify() then begin
                    dataLogHandler.LogItemUpdate(itemNo, Format(newCreatedOn), Format(oldCreatedOn), Enum::PerfionValueType::PerfionCreatedOn, modified);
                    changeCount += 1;
                end
                else
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updatePerfionCreatedOn', Enum::ErrorType::Catch, itemNo, GetLastErrorText());
            end;
        end;
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
                    dataLogHandler.LogItemUpdate(itemNo, newDescription, oldDescription, Enum::PerfionValueType::Description, modified);
                    changeCount += 1;
                end
                else
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updateItemDescription', Enum::ErrorType::Catch, itemNo, GetLastErrorText());
            end;
        end;
    end;

    local procedure WasFieldModifiedAfterSync(itemNo: Code[20]; fieldCaption: Text; lastSync: DateTime): Boolean
    var
        changeLogEntry: Record "Change Log Entry";
    begin
        changeLogEntry.SetRange("Table Caption", 'Item');
        changeLogEntry.SetRange("Field Caption", fieldCaption);
        changeLogEntry.SetRange("Primary Key Field 1 Value", itemNo);
        changeLogEntry.SetFilter("Date and Time", '>%1', lastSync);

        exit(changeLogEntry.FindFirst());
    end;


    local procedure updateItemUserNotes(itemNo: Code[20]; newUserNotes: Text; modified: DateTime)
    var
        oldUserNotes: Text;
        recItem: Record Item;
    begin
        recItem.Reset();
        recItem.SetFilter("No.", itemNo);
        if recItem.FindFirst() then begin
            if recItem.userNotes <> newUserNotes then begin
                oldUserNotes := recItem.userNotes;
                recItem.userNotes := newUserNotes;
                if recItem.Modify() then begin
                    dataLogHandler.LogItemUpdate(itemNo, newUserNotes, oldUserNotes, Enum::PerfionValueType::UserNotes, modified);
                    changeCount += 1;
                end
                else
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updateItemUserNotes', Enum::ErrorType::Catch, itemNo, GetLastErrorText());
            end;
        end;
    end;

    local procedure updateItemApplications(itemNo: Code[20]; newApplications: Text; modified: DateTime)
    var
        oldApplications: Text;
        recItem: Record Item;

    begin
        recItem.Reset();
        recItem.SetFilter("No.", itemNo);
        if recItem.FindFirst() then begin
            if recItem.application <> newApplications then begin
                oldApplications := recItem.application;
                recItem.application := newApplications;
                if recItem.Modify() then begin
                    dataLogHandler.LogItemUpdate(itemNo, newApplications, oldApplications, Enum::PerfionValueType::Applications, modified);
                    changeCount += 1;
                end
                else
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updateItemApplications', Enum::ErrorType::Catch, itemNo, GetLastErrorText());
            end;
        end;
    end;

    local procedure updateItemPicture(itemNo: Code[20]; newStatusText: Text; modified: DateTime)
    var
        recItem: Record Item;
        oldStatus: Enum "PerfionPictureStatus";
        newStatus: Enum "PerfionPictureStatus";
    begin
        recItem.SetRange("No.", itemNo);
        if recItem.FindFirst() then begin

            // Convert Text to Enum
            case newStatusText of
                'Unassigned':
                    newStatus := PerfionPictureStatus::"Unassigned";
                'Needed':
                    newStatus := PerfionPictureStatus::"Needed";
                'Completed':
                    newStatus := PerfionPictureStatus::"Completed";
                'Excluded':
                    newStatus := PerfionPictureStatus::"Excluded";
                'Retake Needed':
                    newStatus := PerfionPictureStatus::"Retake Needed";
                else
                    logManager.logError(
                        Enum::AppCode::Perfion,
                        Enum::AppProcess::"Data Sync In",
                        'updateItemPicture Enum Conversion',
                        Enum::ErrorType::Catch,
                        itemNo,
                        GetLastErrorText()
                    );
            end;

            if recItem.PerfionPicture <> newStatus then begin
                oldStatus := recItem.PerfionPicture;
                recItem.PerfionPicture := newStatus;

                if recItem.Modify() then
                    dataLogHandler.LogItemUpdate(
                        itemNo,
                        Format(newStatus), // log as text
                        Format(oldStatus),
                        Enum::PerfionValueType::Picture,
                        modified
                    )
                else
                    logManager.logError(
                        Enum::AppCode::Perfion,
                        Enum::AppProcess::"Data Sync In",
                        'updateItemPicture',
                        Enum::ErrorType::Catch,
                        itemNo,
                        GetLastErrorText()
                    );

                changeCount += 1;
            end;
        end;
    end;

    local procedure updatePictureInstructions(itemNo: Code[20]; newInstructions: Text; modified: DateTime)
    var
        recItem: Record Item;
        oldInstructions: Text;

    begin
        recItem.Reset();
        recItem.SetFilter("No.", itemNo);
        if recItem.FindFirst() then begin
            if recItem.PictureInstructions <> newInstructions then begin
                oldInstructions := recItem.PictureInstructions;
                recItem.PictureInstructions := newInstructions;
                if recItem.Modify() then begin
                    dataLogHandler.LogItemUpdate(itemNo, PadStr(newInstructions, 400), oldInstructions, Enum::PerfionValueType::PictureInstructions, modified);
                    changeCount += 1;
                end
                else
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updatePictureInstructions', Enum::ErrorType::Catch, itemNo, GetLastErrorText());
            end;
        end;
    end;

    local procedure updatePerfionUserNotes(itemNo: Code[20]; newNotes: Text; modified: DateTime)
    var
        recItem: Record Item;
        oldNotes: Text;

    begin
        recItem.Reset();
        recItem.SetFilter("No.", itemNo);
        if recItem.FindFirst() then begin
            if recItem.PerfionUserNotes <> newNotes then begin
                oldNotes := recItem.PerfionUserNotes;
                recItem.PerfionUserNotes := newNotes;
                if recItem.Modify() then begin
                    dataLogHandler.LogItemUpdate(itemNo, PadStr(newNotes, 2048), oldNotes, Enum::PerfionValueType::PerfionUserNotes, modified);
                    changeCount += 1;
                end
                else
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updatePerfionUserNotes', Enum::ErrorType::Catch, itemNo, GetLastErrorText());
            end;
        end;
    end;


    local procedure updateEnrichStatus(itemNo: Code[20]; newStatus: Text; modified: DateTime)
    var
        oldStatus: Enum PerfionSlsMgrEnrichStatus;
        recItem: Record Item;
        enumStatus: Enum PerfionSlsMgrEnrichStatus;
        oldStatusText: Text;
        newStatusText: Text;

    begin
        recItem.Reset();
        recItem.SetFilter("No.", itemNo);
        if recItem.FindFirst() then begin
            // Get the current status value
            oldStatus := recItem.SlsMgrEnrichStatus;
            // Convert incoming integer to enum value
            case newStatus of
                'Work':
                    enumStatus := Enum::PerfionSlsMgrEnrichStatus::Work;
                'Review':
                    enumStatus := Enum::PerfionSlsMgrEnrichStatus::Review;
                'Paused':
                    enumStatus := Enum::PerfionSlsMgrEnrichStatus::Paused;
                'Rejected':
                    enumStatus := Enum::PerfionSlsMgrEnrichStatus::Rejected;
                'Reject from Workflow':
                    enumStatus := Enum::PerfionSlsMgrEnrichStatus::"Reject from Workflow";
                'Paused for Later Project':
                    enumStatus := Enum::PerfionSlsMgrEnrichStatus::"Paused for Later Project";
                'Complete':
                    enumStatus := Enum::PerfionSlsMgrEnrichStatus::Complete;
                'N/A':
                    enumStatus := Enum::PerfionSlsMgrEnrichStatus::"N/A";
                else begin
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updateEnrichStatus', Enum::ErrorType::Catch, itemNo, 'Invalid Enrich Status value: ' + Format(newStatus));
                    exit;
                end;
            end;

            // Convert enum values to text
            oldStatusText := Format(oldStatus);
            newStatusText := Format(enumStatus);

            if oldStatus <> enumStatus then begin
                recItem.SlsMgrEnrichStatus := enumStatus;
                if recItem.Modify() then begin
                    dataLogHandler.LogItemUpdate(itemNo, newStatusText, oldStatusText, Enum::PerfionValueType::SlsMgrEnrichStatus, modified);
                    changeCount += 1;
                end
                else
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updateEnrichStatus', Enum::ErrorType::Catch, itemNo, GetLastErrorText());
            end;
        end;
    end;

    local procedure updateItemVisibility(itemNo: Code[20]; newVisibility: Integer; modified: DateTime)
    var
        oldVisibility: Enum PerfionMagentoVisibilityType;
        recItem: Record Item;
        enumVisibility: Enum PerfionMagentoVisibilityType;
        oldVisibilityText: Text;
        newVisibilityText: Text;

    begin
        recItem.Reset();
        recItem.SetFilter("No.", itemNo);
        if recItem.FindFirst() then begin
            // Get the current visibility value
            oldVisibility := recItem.MagentoVisibility;
            // Convert incoming integer to enum value
            case newVisibility of
                1:
                    enumVisibility := Enum::PerfionMagentoVisibilityType::NotVisible;
                2:
                    enumVisibility := Enum::PerfionMagentoVisibilityType::InCatalog;
                3:
                    enumVisibility := Enum::PerfionMagentoVisibilityType::InSearch;
                4:
                    enumVisibility := Enum::PerfionMagentoVisibilityType::Both;
                else begin
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updateItemVisibility', Enum::ErrorType::Catch, itemNo, 'Invalid Magento Visibility value: ' + Format(newVisibility));
                    exit;
                end;
            end;

            // Convert enum values to text
            oldVisibilityText := Format(oldVisibility);
            newVisibilityText := Format(enumVisibility);

            if oldVisibility <> enumVisibility then begin
                recItem.MagentoVisibility := enumVisibility;
                if recItem.Modify() then begin
                    dataLogHandler.LogItemUpdate(itemNo, newVisibilityText, oldVisibilityText, Enum::PerfionValueType::Visibility, modified);
                    changeCount += 1;
                end
                else
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updateItemVisibility', Enum::ErrorType::Catch, itemNo, GetLastErrorText());
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
                    dataLogHandler.LogItemUpdate(itemNo, newCategory, oldCategory, Enum::PerfionValueType::ItemCategory, modified);
                    changeCount += 1;
                end
                else
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updateItemCategory', Enum::ErrorType::Catch, itemNo, GetLastErrorText());
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
                    dataLogHandler.LogItemUpdate(itemNo, Format(newCoreValue), Format(oldCoreValue), Enum::PerfionValueType::CoreValue, modified);
                    changeCount += 1;
                    needSync := true;
                end
                else
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updateCoreValue', Enum::ErrorType::Catch, itemNo, GetLastErrorText());
            end;

            if recItem."Core Resource Name" <> newCoreResource then begin
                oldCoreResource := recItem."Core Resource Name";
                recItem."Core Resource Name" := newCoreResource;

                if recItem.Modify() then begin
                    dataLogHandler.LogItemUpdate(itemNo, Format(newCoreResource), Format(oldCoreResource), Enum::PerfionValueType::CoreResource, modified);
                    changeCount += 1;
                    needSync := true;
                end
                else
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'updateCoreResource', Enum::ErrorType::Catch, itemNo, GetLastErrorText());
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
        jObjSelect.Add('timezone', 'Eastern Standard Time');
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
        features.Add('Category');
        features.Add('PerfionPictureStatus');
        features.Add('PhotographyPickerInstructions');
        features.Add('BCUserNotes');
        features.Add('BCApplications');
        features.Add('Visibility');
        features.Add('P1SalesManagerEnrichStatus');
        features.Add('USERNotes');
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

        if not fullSync then begin
            Clear(jObject);
            jObject.Add('Clause', buildItemModifiedClause());
            jArray.Add(jObject);

            logManager.logInfo(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'DateTo', getToDateText() + ' ' + getToTimeText());
            logManager.logInfo(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'DateFrom', getFromDateText() + ' ' + getFromTimeText());

            jObject.Add('Or', jObjectEmpty);
            jArray.Add(jObject);

            Clear(jObject);
            foreach feature in features do begin
                jObject.Add('Clause', buildClauses(feature));
                jObject.Add('Or', jObjectEmpty);
                jArray.Add(jObject);
                Clear(jObject);
            end;
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

    local procedure buildClauses(featureType: Text): JsonObject
    var
        jObjValue: JsonObject;
        jObjValueDetail: JsonObject;
        jArrValue: JsonArray;

    begin

        //NOTE - example format Perfion expects 2024-05-04 00:00:00"

        jObjValue.Add('id', featureType + '.modifiedDate');
        jObjValue.Add('operator', 'BETWEEN');
        //DEVELOPER - Testing Only
        //jArrValue.Add('2024-05-10 00:00:00');
        //jArrValue.Add('2024-05-10 23:00:00');
        jArrValue.Add(getFromDateText() + ' ' + getFromTimeText());
        jArrValue.Add(getToDateText() + ' ' + getToTimeText());
        jObjValue.Add('value', jArrValue);
        exit(jObjValue);
    end;

    local procedure buildItemModifiedClause(): JsonObject
    var
        jObjValue: JsonObject;
        jObjValueDetail: JsonObject;
        jArrValue: JsonArray;

    begin

        //NOTE - example format Perfion expects 2024-05-04 00:00:00"

        jObjValue.Add('id', 'modifiedDate');
        jObjValue.Add('operator', 'BETWEEN');
        //DEVELOPER - Testing Only
        //jArrValue.Add('2024-05-10 00:00:00');
        //jArrValue.Add('2024-05-10 23:00:00');
        jArrValue.Add(getFromDateText() + ' ' + getFromTimeText());
        jArrValue.Add(getToDateText() + ' ' + getToTimeText());
        jObjValue.Add('value', jArrValue);
        exit(jObjValue);
    end;

    local procedure getFromDateText(): Text
    begin
        exit(Format(perfionDataSyncIn.LastSync, 0, '<Year4>-<Month,2>-<Day,2>'));
    end;

    local procedure getFromTimeText(): Text
    begin
        exit(Format(perfionDataSyncIn.LastSync, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>'));
    end;

    local procedure getToDateText(): Text
    begin
        exit(Format(currDateTime, 0, '<Year4>-<Month,2>-<Day,2>'));
    end;

    local procedure getToTimeText(): Text
    begin
        exit(Format(currDateTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>'));
    end;

    var
        fullSync: Boolean;
        dataLogHandler: Codeunit PerfionDataInLogHandler;
        changeCount: Integer;
        apiHandler: Codeunit PerfionApiHandler;
        currentItem: Code[20];
        perfionDataSyncIn: Record PerfionDataSyncIn;
        currDateTime: DateTime;
        perfionConfig: Record PerfionConfig;
        logManager: Codeunit LogManager;
        lastPerfionSync: DateTime;

    /*

    Example of post to send to Perfion to get results

{
   "Query": 
   {
      "Select": 
      {
         "languages": "EN",
         "maxCount": "100",
         "timezone": "Eastern Standard Time",
         "options": "IncludeTotalCount,ExcludeFeatureDefinitions",
         "Features": [
            { "id": "PartNameProductDescription" },
            { "id": "SAGroup2" },
            { "id": "CoreResourceName"},
            { "id": "Core"},
            { "id": "Category" },
            { "id": "PictureLocation"},
            { "id": "PhotographyPickerInstructions"},
            { "id": "BCUserNotes"},
            { "id": "BCApplications"},
            { "id": "Visibility"},
            { "id": "P1SalesManagerEnrichStatus"},
            { "id": "USERNotes"}
        ]
      },
        "From": [ 
            { "id": "100" }
        ],
      "Where": {
         "Clauses": [ 
             { "Clause": { "id": "brand", "operator": "=", "value": "Normal" } },
             { "Clause": { "id": "BCItemType", "operator": "IN", "value": [ "Assembly", "Prod. Order", "Purchase" ] } },
             { "Clause": { "id": "modifiedDate", "operator": "BETWEEN", "value": [ "2024-11-22 07:00:00", "2024-11-22 11:04:00" ] }},
             { "Or": {} },
             { "Clause": { "id": "PartNameProductDescription.modifiedDate", "operator": "BETWEEN", "value": [ "2024-11-22 07:00:00", "2024-11-22 11:04:00" ] }
             },
            { "Or": {} },
             { "Clause": { "id": "SAGroup2.modifiedDate", "operator": "BETWEEN", "value": [ "2024-11-22 07:00:00", "2024-11-22 11:04:00" ] }
             },
            { "Or": {} },
             { "Clause": { "id": "CoreResourceName.modifiedDate", "operator": "BETWEEN", "value": [ "2024-11-22 07:00:00", "2024-11-22 11:04:00" ] }
             },
            { "Or": {} },
             { "Clause": { "id": "Core.modifiedDate", "operator": "BETWEEN", "value": [ "2024-11-22 07:00:00", "2024-11-22 11:04:00" ] }
             },
             { "Or": {} },
             { "Clause": { "id": "PictureLocation.modifiedDate", "operator": "BETWEEN", "value": [ "2024-11-22 07:00:00", "2024-11-22 11:04:00" ] }
             },
             { "Or": {} },
             { "Clause": { "id": "PhotographyPickerInstructions.modifiedDate", "operator": "BETWEEN", "value": [ "2024-11-22 07:00:00", "2024-11-22 11:04:00" ] }
             },
             { "Or": {} },
             { "Clause": { "id": "BCUserNotes.modifiedDate", "operator": "BETWEEN", "value": [ "2024-11-22 07:00:00", "2024-11-22 11:04:00" ] }
             },
             { "Or": {} },
             { "Clause": { "id": "BCApplications.modifiedDate", "operator": "BETWEEN", "value": [ "2024-11-22 07:00:00", "2024-11-22 11:04:00" ] }
             }
         ]
      }
   }
}
    */
}