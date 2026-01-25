codeunit 50368 PerfionDataSyncIn
{
    // This codeunit is a refactored version of the original PerfionDataSyncIn.
    // It implements the "Collect, Then Commit" pattern to dramatically improve performance
    // by minimizing database read/write operations and reducing transaction duration.

    trigger OnRun()
    var
        perfionSyncIn: Record PerfionDataSyncIn;
        ProfilerConfig: Codeunit AmProfilerConfig;
        Profiler: Codeunit AbileneProfiler;
        t: Time;
        tOnRun: Time;
    begin
        Profiler.BeginRun(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", ProfilerConfig.IsEnabled(), ProfilerConfig.GetThresholdSec());
        Profiler.Start('onRun', tOnRun);
        currDateTime := CurrentDateTime;
        if perfionSyncIn.Get() then
            lastPerfionSync := perfionSyncIn.LastSync;

        if perfionConfig.Get() then begin
            if (isAfter6pm()) or (perfionConfig.fullSync) then
                fullSync := true
            else
                fullSync := false;

            if perfionDataSyncIn.Get() then begin
                changeCount := 0;
                Profiler.Start('startPerfionRequest', t);
                startPerfionRequest();
                Profiler.Stop('startPerfionRequest', t, '', '');
            end;
        end;
        Profiler.Stop('onRun', tOnRun, '', '');
        Profiler.Flush();
    end;

    local procedure startPerfionRequest()
    var
        CallResponse: Text;
        Content: Text;
        ErrorList: List of [Text];
        ErrorListMsg: Text;
        Profiler: Codeunit AbileneProfiler;
        t: Time;
    begin
        Content := GenerateQueryContent();
        if not apiHandler.perfionPostRequest(CallResponse, ErrorList, Content) then begin
            logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'startPerfionRequest', Enum::ErrorType::Catch, GetLastErrorText());
            exit;
        end;

        if ErrorList.Count > 0 then begin
            foreach ErrorListMsg in ErrorList do
                logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'startPerfionRequest', Enum::ErrorType::Crash, ErrorListMsg);
            exit;
        end;
        Profiler.Start('processPerfionResponse', t);
        processPerfionResponse(CallResponse);
        Profiler.Stop('processPerfionResponse', t, '', '');

    end;

    local procedure processPerfionResponse(response: Text)
    var
        recItem: Record Item;
        responseObject: JsonObject;
        dataToken, totalToken, itemsToken, valuesToken, valueItemToken, itemNumToken : JsonToken;
        itemDateCreated, itemDateModified, itemFeatureValue, itemFeatureName, featureId : JsonToken;
        // NEW: per-item top-level modified
        itemTopLevelModifiedToken: JsonToken;
        itemTopLevelModifiedAtUtc: DateTime;
        itemTopLevelModifiedText, modifiedDateTimeText : Text;
        itemNum: Code[20];
        tempCoreResource: Code[20];
        tempPicInstructions: Text;
        tempApplications, tempUserNotes : Text;
        tempCoreValue: Decimal;
        tempItemDateModified, createdDateTime, modifiedDateTime : DateTime;
        hasCore, hasPicInstructions, hasApplications, hasUserNotes, itemModified : Boolean;
        didNotesInbound, didAppsInbound : Boolean;
        Profiler: Codeunit AbileneProfiler;
        t: Time;
        State: Record "Perfion Field Sync State";
        StateMgt: Codeunit "PerfionSyncStateMgt";
    begin
        responseObject.ReadFrom(response);
        if not responseObject.SelectToken('Data', dataToken) then exit;
        if not dataToken.SelectToken('totalCount', totalToken) then exit;

        if totalToken.AsValue().AsInteger() = 0 then begin
            UpdateSyncStatus(0, 0);
            exit;
        end;

        if not dataToken.SelectToken('Items', itemsToken) then exit;
        Profiler.Start('itemsToken.AsArray', t);

        foreach itemsToken in itemsToken.AsArray() do begin
            if not itemsToken.SelectToken('Values', valuesToken) then Continue;
            if valuesToken.AsArray().Count = 0 then Continue;

            valuesToken.AsArray().Get(0, valueItemToken);
            if not valueItemToken.SelectToken('value', itemNumToken) then Continue;

            itemNum := CopyStr(itemNumToken.AsValue().AsCode(), 1, MaxStrLen(itemNum));
            if not IsValidItem(itemNum) then Continue;

            // NEW: capture Items[].modifiedDate (top-level)
            if itemsToken.SelectToken('modifiedDate', itemTopLevelModifiedToken) then begin
                itemTopLevelModifiedText := itemTopLevelModifiedToken.AsValue().AsText();
                itemTopLevelModifiedAtUtc := PerfionEasternTextToUtc(itemTopLevelModifiedText);
            end;

            recItem.Reset();
            SetItemLoadFields(recItem);
            if not recItem.Get(itemNum) then begin
                logManager.logInfo(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'processPerfionResponse.Get', itemNum, 'Item not in BC');
                Continue;
            end;

            if recItem.Blocked then begin
                logManager.logInfo(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'processPerfionResponse.Blocked', itemNum, 'Item blocked in BC');
                Continue;
            end;

            // Initialize variables for the current item processing
            Clear(hasCore);
            Clear(hasPicInstructions);
            Clear(hasUserNotes);
            Clear(hasApplications);
            Clear(tempCoreResource);
            Clear(tempCoreValue);
            Clear(tempPicInstructions);
            Clear(tempApplications);
            Clear(tempUserNotes);
            itemModified := false;
            didNotesInbound := false;
            didAppsInbound := false;

            if itemsToken.SelectToken('createdDate', itemDateCreated) then begin
                createdDateTime := itemDateCreated.AsValue().AsDateTime();
                updatePerfionCreatedOn(recItem, createdDateTime, itemModified);
            end;

            foreach valuesToken in valuesToken.AsArray() do begin
                if not valuesToken.SelectToken('featureId', featureId) then Continue;
                if featureId.AsValue().AsInteger() = 100 then Continue;

                valuesToken.SelectToken('value', itemFeatureValue);
                valuesToken.SelectToken('featureName', itemFeatureName);
                valuesToken.SelectToken('modifiedDate', itemDateModified);
                //modifiedDateTime := itemDateModified.AsValue().AsDateTime();
                modifiedDateTimeText := itemDateModified.AsValue().AsText();
                modifiedDateTime := PerfionEasternTextToUtc(modifiedDateTimeText);

                case itemFeatureName.AsValue().AsText() of
                    'PartNameProductDescription':
                        updateItemDescription(recItem, itemFeatureValue.AsValue().AsText(), modifiedDateTime, itemModified);
                    'SAGroup2':
                        updateItemCategory(recItem, itemFeatureValue.AsValue().AsCode(), modifiedDateTime, itemModified);
                    'PerfionPictureStatus':
                        updateItemPicture(recItem, itemFeatureValue.AsValue().AsText(), modifiedDateTime, itemModified);
                    'Visibility':
                        updateItemVisibility(recItem, itemFeatureValue.AsValue().AsInteger(), modifiedDateTime, itemModified);
                    'P1SalesManagerEnrichStatus':
                        updateEnrichStatus(recItem, itemFeatureValue.AsValue().AsText(), modifiedDateTime, itemModified);
                    'USERNotes':
                        updatePerfionUserNotes(recItem, CopyStr(itemFeatureValue.AsValue().AsText(), 1, 50), modifiedDateTime, itemModified);
                    'BCUserNotes':
                        begin
                            hasUserNotes := true;
                            tempUserNotes := itemFeatureValue.AsValue().AsText();
                            //tempItemDateModified := modifiedDateTime;
                        end;
                    'BCApplications':
                        begin
                            hasApplications := true;
                            tempApplications := itemFeatureValue.AsValue().AsText();
                            //tempItemDateModified := modifiedDateTime;
                        end;
                    'PhotographyPickerInstructions':
                        begin
                            hasPicInstructions := true;
                            tempPicInstructions := itemFeatureValue.AsValue().AsText();
                            tempItemDateModified := modifiedDateTime;
                        end;
                    'CoreResourceName':
                        tempCoreResource := itemFeatureValue.AsValue().AsCode();
                    'Core':
                        begin
                            hasCore := true;
                            tempCoreValue := itemFeatureValue.AsValue().AsDecimal();
                            tempItemDateModified := modifiedDateTime;
                        end;
                end;
            end;

            updateCoreData(recItem, tempCoreResource, tempCoreValue, hasCore, tempItemDateModified, itemModified);
            updatePictureInstructions(recItem, tempPicInstructions, hasPicInstructions, tempItemDateModified, itemModified);
            updateItemUserNotes(recItem, tempUserNotes, hasUserNotes, itemTopLevelModifiedAtUtc, itemModified, didNotesInbound);
            updateItemApplications(recItem, tempApplications, hasApplications, itemTopLevelModifiedAtUtc, itemModified, didAppsInbound);

            if itemModified then begin
                if recItem.Modify(true) then
                    changeCount += 1
                else
                    logManager.logError(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'processPerfionResponse.Modify', Enum::ErrorType::Catch, recItem."No.", GetLastErrorText());
            end;

            if didNotesInbound or didAppsInbound then begin
                StateMgt.GetOrCreate(State, recItem."No.");
                if didNotesInbound then begin
                    State."Notes Last Inbound At" := CurrentDateTime();
                    State."Notes Awaiting Ack" := false;
                end;
                if didAppsInbound then begin
                    State."Apps Last Inbound At" := CurrentDateTime();
                    State."Apps Awaiting Ack" := false;
                end;
                State.Modify();
            end;
        end;

        Profiler.Stop('itemsToken.AsArray', t, '', '');

        UpdateSyncStatus(changeCount, totalToken.AsValue().AsInteger());
    end;

    local procedure IsValidItem(itemNo: Code[20]): Boolean
    begin
        if StrLen(itemNo) > 20 then begin
            logManager.logInfo(Enum::AppCode::Perfion, Enum::AppProcess::"Data Sync In", 'IsValidItem', itemNo, 'Item No too long');
            exit(false);
        end;
        exit(true);
    end;

    local procedure updatePerfionCreatedOn(var recItem: Record Item; newCreatedOn: DateTime; var itemModified: Boolean)
    var
        oldCreatedOn: DateTime;
    begin
        if recItem.PerfionCreatedOn < newCreatedOn then begin
            oldCreatedOn := recItem.PerfionCreatedOn;
            recItem.PerfionCreatedOn := newCreatedOn;
            itemModified := true;
            dataLogHandler.LogItemUpdate(recItem."No.", Format(newCreatedOn), Format(oldCreatedOn), Enum::PerfionValueType::PerfionCreatedOn, newCreatedOn);
        end;
    end;

    local procedure updateItemDescription(var recItem: Record Item; newDescription: Text; modified: DateTime; var itemModified: Boolean)
    var
        oldDescription: Text;
    begin
        if recItem.Description <> newDescription then begin
            oldDescription := recItem.Description;
            recItem.Description := newDescription;
            itemModified := true;
            dataLogHandler.LogItemUpdate(recItem."No.", newDescription, oldDescription, Enum::PerfionValueType::Description, modified);
        end;
    end;

    local procedure updateItemCategory(var recItem: Record Item; newCategory: Code[20]; modified: DateTime; var itemModified: Boolean)
    var
        oldCategory: Code[20];
    begin
        if recItem."Item Category Code" <> newCategory then begin
            oldCategory := recItem."Item Category Code";
            recItem."Item Category Code" := newCategory;
            itemModified := true;
            dataLogHandler.LogItemUpdate(recItem."No.", newCategory, oldCategory, Enum::PerfionValueType::ItemCategory, modified);
        end;
    end;

    local procedure updateItemPicture(var recItem: Record Item; newStatusText: Text; modified: DateTime; var itemModified: Boolean)
    var
        oldStatus: Enum "PerfionPictureStatus";
        newStatus: Enum "PerfionPictureStatus";
    begin
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
                exit;
        end;

        if recItem.PerfionPicture <> newStatus then begin
            oldStatus := recItem.PerfionPicture;
            recItem.PerfionPicture := newStatus;
            itemModified := true;
            dataLogHandler.LogItemUpdate(recItem."No.", Format(newStatus), Format(oldStatus), Enum::PerfionValueType::Picture, modified);
        end;
    end;

    local procedure updateItemVisibility(var recItem: Record Item; newVisibility: Integer; modified: DateTime; var itemModified: Boolean)
    var
        oldVisibility: Enum PerfionMagentoVisibilityType;
        enumVisibility: Enum PerfionMagentoVisibilityType;
    begin
        case newVisibility of
            1:
                enumVisibility := Enum::PerfionMagentoVisibilityType::NotVisible;
            2:
                enumVisibility := Enum::PerfionMagentoVisibilityType::InCatalog;
            3:
                enumVisibility := Enum::PerfionMagentoVisibilityType::InSearch;
            4:
                enumVisibility := Enum::PerfionMagentoVisibilityType::Both;
            else
                exit;
        end;

        if recItem.MagentoVisibility <> enumVisibility then begin
            oldVisibility := recItem.MagentoVisibility;
            recItem.MagentoVisibility := enumVisibility;
            itemModified := true;
            dataLogHandler.LogItemUpdate(recItem."No.", Format(enumVisibility), Format(oldVisibility), Enum::PerfionValueType::Visibility, modified);
        end;
    end;

    local procedure updateEnrichStatus(var recItem: Record Item; newStatus: Text; modified: DateTime; var itemModified: Boolean)
    var
        oldStatus: Enum PerfionSlsMgrEnrichStatus;
        enumStatus: Enum PerfionSlsMgrEnrichStatus;
    begin
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
            else
                exit;
        end;

        if recItem.SlsMgrEnrichStatus <> enumStatus then begin
            oldStatus := recItem.SlsMgrEnrichStatus;
            recItem.SlsMgrEnrichStatus := enumStatus;
            itemModified := true;
            dataLogHandler.LogItemUpdate(recItem."No.", Format(enumStatus), Format(oldStatus), Enum::PerfionValueType::SlsMgrEnrichStatus, modified);
        end;
    end;

    local procedure updatePerfionUserNotes(var recItem: Record Item; newNotes: Text; modified: DateTime; var itemModified: Boolean)
    var
        oldNotes: Text;
    begin
        if recItem.PerfionUserNotes <> newNotes then begin
            oldNotes := recItem.PerfionUserNotes;
            recItem.PerfionUserNotes := newNotes;
            itemModified := true;
            dataLogHandler.LogItemUpdate(recItem."No.", newNotes, oldNotes, Enum::PerfionValueType::PerfionUserNotes, modified);
        end;
    end;

    local procedure updateCoreData(var recItem: Record Item; newCoreResource: Code[20]; newCoreValue: Decimal; hasCore: Boolean; modified: DateTime; var itemModified: Boolean)
    var
        oldCoreValue: Decimal;
        oldCoreResource: Code[20];
        needSync: Boolean;
        magentoSync: Codeunit MagentoDataSync;
    begin
        if not hasCore then begin
            newCoreResource := '';
            newCoreValue := 0;
        end;

        if recItem."Core Sales Value" <> newCoreValue then begin
            oldCoreValue := recItem."Core Sales Value";
            recItem."Core Sales Value" := newCoreValue;
            itemModified := true;
            needSync := true;
            dataLogHandler.LogItemUpdate(recItem."No.", Format(newCoreValue), Format(oldCoreValue), Enum::PerfionValueType::CoreValue, modified);
        end;

        if recItem."Core Resource Name" <> newCoreResource then begin
            oldCoreResource := recItem."Core Resource Name";
            recItem."Core Resource Name" := newCoreResource;
            itemModified := true;
            needSync := true;
            dataLogHandler.LogItemUpdate(recItem."No.", newCoreResource, oldCoreResource, Enum::PerfionValueType::CoreResource, modified);
        end;

        if needSync then
            magentoSync.sendCoreData(recItem."No.");
    end;

    local procedure updatePictureInstructions(var recItem: Record Item; newInstructions: Text; hasPicInstructions: Boolean; modified: DateTime; var itemModified: Boolean)
    var
        oldInstructions: Text;
        finalInstructions: Text;
    begin
        if hasPicInstructions then
            finalInstructions := newInstructions
        else
            finalInstructions := '';

        if recItem.PictureInstructions <> finalInstructions then begin
            oldInstructions := recItem.PictureInstructions;
            recItem.PictureInstructions := finalInstructions;
            itemModified := true;
            dataLogHandler.LogItemUpdate(recItem."No.", PadStr(finalInstructions, 400), oldInstructions, Enum::PerfionValueType::PictureInstructions, modified);
        end;
    end;

    local procedure updateItemUserNotes(
    var recItem: Record Item;
    newUserNotes: Text;
    hasUserNotes: Boolean;            // TRUE only if BCUserNotes feature exists in JSON
    perfionItemModifiedAt: DateTime;  // Items[].modifiedDate (top-level) from Perfion
    var itemModified: Boolean;
    var didNotesInbound: Boolean)
    var
        State: Record "Perfion Field Sync State";
        StateMgt: Codeunit "PerfionSyncStateMgt";
        outboundCursor: DateTime;
        inboundCursor: DateTime;
        baseCursor: DateTime;
        haveBCChange: Boolean;
        latestBCAt: DateTime;
        latestBCBy: Code[50];
        finalTxt: Text;
        oldTxt: Text;
    begin
        didNotesInbound := false;

        // 1) Ensure state and compute baseCursor
        StateMgt.GetOrCreate(State, recItem."No.");
        outboundCursor := State."Notes Last Outbound At";
        inboundCursor := State."Notes Last Inbound At";
        baseCursor := outboundCursor;
        if inboundCursor > baseCursor then
            baseCursor := inboundCursor;

        // 2) Probe Change Log AFTER baseCursor
        haveBCChange :=
            GetLatestBCChangeAfter(recItem."No.", recItem.FieldNo(UserNotes), baseCursor, latestBCAt, latestBCBy);

        // 3) INCLUDE case: Perfion sent a value
        if hasUserNotes then begin
            // If BC changed later than Perfion, BC wins → skip
            if haveBCChange and (latestBCAt > perfionItemModifiedAt) then
                exit;

            // Normalize and apply if changed
            finalTxt := CopyStr(TrimBoth(newUserNotes), 1, MaxStrLen(recItem.UserNotes));
            if recItem.UserNotes <> finalTxt then begin
                oldTxt := recItem.UserNotes;
                recItem.UserNotes := finalTxt;
                itemModified := true;
                didNotesInbound := true;
                dataLogHandler.LogItemUpdate(recItem."No.", finalTxt, oldTxt, Enum::PerfionValueType::UserNotes, perfionItemModifiedAt);
            end;
            exit;
        end;

        // 4) OMISSION case: Perfion omitted → treat as clear
        // Clear only if Perfion changed after our baseCursor AND BC does NOT have a later edit than Perfion
        if (perfionItemModifiedAt > baseCursor) and (not haveBCChange or (latestBCAt <= perfionItemModifiedAt)) then begin
            if recItem.UserNotes <> '' then begin
                oldTxt := recItem.UserNotes;
                recItem.UserNotes := '';
                itemModified := true;
                didNotesInbound := true;
                dataLogHandler.LogItemUpdate(recItem."No.", '', oldTxt, Enum::PerfionValueType::UserNotes, perfionItemModifiedAt);
            end;
        end;
    end;

    local procedure updateItemApplications(
    var recItem: Record Item;
    newApplications: Text;
    hasApplications: Boolean;         // TRUE only if BCApplications feature exists in JSON
    perfionItemModifiedAt: DateTime;  // Items[].modifiedDate (top-level) from Perfion
    var itemModified: Boolean;
    var didApplicationsInbound: Boolean)
    var
        State: Record "Perfion Field Sync State";
        StateMgt: Codeunit "PerfionSyncStateMgt";
        outboundCursor: DateTime;
        inboundCursor: DateTime;
        baseCursor: DateTime;
        haveBCChange: Boolean;
        latestBCAt: DateTime;
        latestBCBy: Code[50];
        finalTxt: Text;
        oldTxt: Text;
    begin
        didApplicationsInbound := false;

        // 1) Ensure state and compute baseCursor
        StateMgt.GetOrCreate(State, recItem."No.");
        outboundCursor := State."Apps Last Outbound At";
        inboundCursor := State."Apps Last Inbound At";
        baseCursor := outboundCursor;
        if inboundCursor > baseCursor then
            baseCursor := inboundCursor;

        // 2) Probe Change Log AFTER baseCursor
        haveBCChange :=
            GetLatestBCChangeAfter(recItem."No.", recItem.FieldNo(application), baseCursor, latestBCAt, latestBCBy);

        // 3) INCLUDE case: Perfion sent a value
        if hasApplications then begin
            // If BC changed later than Perfion, BC wins → skip
            if haveBCChange and (latestBCAt > perfionItemModifiedAt) then
                exit;

            // Normalize and apply if changed
            finalTxt := CopyStr(TrimBoth(newApplications), 1, MaxStrLen(recItem.application));
            if recItem.application <> finalTxt then begin
                oldTxt := recItem.application;
                recItem.application := finalTxt;
                itemModified := true;
                didApplicationsInbound := true;
                dataLogHandler.LogItemUpdate(recItem."No.", finalTxt, oldTxt, Enum::PerfionValueType::Applications, perfionItemModifiedAt);
            end;
            exit;
        end;

        // 4) OMISSION case: Perfion omitted → treat as clear
        if (perfionItemModifiedAt > baseCursor) and (not haveBCChange or (latestBCAt <= perfionItemModifiedAt)) then begin
            if recItem.application <> '' then begin
                oldTxt := recItem.application;
                recItem.application := '';
                itemModified := true;
                didApplicationsInbound := true;
                dataLogHandler.LogItemUpdate(recItem."No.", '', oldTxt, Enum::PerfionValueType::Applications, perfionItemModifiedAt);
            end;
        end;
    end;



    local procedure GetLatestBCChangeAfter(ItemNo: Code[20]; FieldNo: Integer; Cursor: DateTime; var ChangedAt: DateTime; var ChangedBy: Code[50]): Boolean
    var
        CLE: Record "Change Log Entry";
    begin
        Clear(ChangedAt);
        Clear(ChangedBy);

        CLE.Reset();
        CLE.SetRange("Table No.", Database::Item);
        CLE.SetRange("Field No.", FieldNo);
        CLE.SetRange("Primary Key Field 1 Value", ItemNo);
        CLE.SetFilter("Date and Time", '>%1', Cursor);
        CLE.SetCurrentKey("Date and Time");  // newest last
        if CLE.FindLast() then begin
            ChangedAt := CLE."Date and Time";
            ChangedBy := CLE."User ID";
            exit(true);
        end;
        exit(false);
    end;


    local procedure TrimBoth(Value: Text): Text
    begin
        // remove leading spaces
        Value := DelChr(Value, '<', ' ');
        // remove trailing spaces
        exit(DelChr(Value, '>', ' '));
    end;

    local procedure SetItemLoadFields(var recItem: Record Item)
    begin
        recItem.SetLoadFields(
            "No.", Blocked, Description, "Item Category Code", PerfionPicture,
            MagentoVisibility, SlsMgrEnrichStatus, PerfionUserNotes, userNotes,
            application, PictureInstructions, "Core Resource Name", "Core Sales Value",
            PerfionCreatedOn
        );
    end;

    local procedure UpdateSyncStatus(processedCount: Integer; totalCount: Integer)
    begin
        perfionDataSyncIn.Processed := processedCount;
        perfionDataSyncIn.TotalCount := totalCount;
        perfionDataSyncIn.LastSync := currDateTime;
        perfionDataSyncIn.Modify();

        if fullSync then begin
            perfionConfig.fullSync := false;
            perfionConfig.Modify();
        end;
    end;

    procedure isAfter6pm(): Boolean
    var
        MyTime: Time;
        CurrentTime: Time;
    begin
        MyTime := 180000T; // 6:00:00 PM
        CurrentTime := Time();
        exit(CurrentTime >= MyTime);
    end;

    local procedure GenerateQueryContent(): Text
    var
        jObjQuery, jObjQueryInner, jObjSelect, jObjFrom, jObjClause : JsonObject;
        jArrFrom: JsonArray;
    begin
        jObjSelect.Add('languages', 'EN');
        jObjSelect.Add('timezone', 'Eastern Standard Time');
        jObjSelect.Add('options', 'IncludeTotalCount,ExcludeFeatureDefinitions');
        jObjSelect.Add('Features', buildFeatures());
        jObjQueryInner.Add('Select', jObjSelect);

        jObjFrom.Add('id', '100');
        jArrFrom.Add(jObjFrom);
        jObjQueryInner.Add('From', jArrFrom);

        jObjClause.Add('Clauses', buildClauseArray());
        jObjQueryInner.Add('Where', jObjClause);

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
            Clear(jObject);
            jObject.Add('id', feature);
            jArray.Add(jObject);
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
        jArrValue: JsonArray;
    begin
        jObjValue.Add('id', featureType + '.modifiedDate');
        jObjValue.Add('operator', 'BETWEEN');
        jArrValue.Add(getFromDateText() + ' ' + getFromTimeText());
        jArrValue.Add(getToDateText() + ' ' + getToTimeText());
        jObjValue.Add('value', jArrValue);
        exit(jObjValue);
    end;

    local procedure buildItemModifiedClause(): JsonObject
    var
        jObjValue: JsonObject;
        jArrValue: JsonArray;
    begin
        jObjValue.Add('id', 'modifiedDate');
        jObjValue.Add('operator', 'BETWEEN');
        jArrValue.Add(getFromDateText() + ' ' + getFromTimeText());
        jArrValue.Add(getToDateText() + ' ' + getToTimeText());
        jObjValue.Add('value', jArrValue);
        exit(jObjValue);
    end;

    local procedure getFromDateText(): Text
    begin
        exit(Format(lastPerfionSync, 0, '<Year4>-<Month,2>-<Day,2>'));
    end;

    local procedure getFromTimeText(): Text
    begin
        exit(Format(lastPerfionSync, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>'));
    end;

    local procedure getToDateText(): Text
    begin
        exit(Format(currDateTime, 0, '<Year4>-<Month,2>-<Day,2>'));
    end;

    local procedure getToTimeText(): Text
    begin
        exit(Format(currDateTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>'));
    end;

    // Parse an EST/EDT timestamp string from Perfion and return UTC DateTime
    local procedure PerfionEasternTextToUtc(tsText: Text): DateTime
    var
        d: Date;
        t: Time;
        dtLocal: DateTime; // clock time in Eastern, no zone attached
        offset: Duration;
    begin
        // Perfion returns e.g. '2025-09-11T13:41:00.000'
        // Extract date + time parts and build a DateTime (still "local clock time")
        Evaluate(d, CopyStr(tsText, 1, 10));        // 'YYYY-MM-DD'
        Evaluate(t, CopyStr(tsText, 12, 8));        // 'HH:MM:SS'
        dtLocal := CreateDateTime(d, t);

        // Determine UTC offset for Eastern on that date (DST-aware)
        if IsEasternDst(d) then
            offset := 4    // EDT = UTC-4  -> to get UTC add +4h
        else
            offset := 5;    // EST = UTC-5  -> to get UTC add +5h

        exit(dtLocal + offset);
    end;

    // True if 'd' falls within US Eastern Daylight Saving Time for that year
    local procedure IsEasternDst(d: Date): Boolean
    var
        y: Integer;
        dstStart: Date; // 2:00 AM local, second Sunday in March
        dstEnd: Date;   // 2:00 AM local, first Sunday in November
    begin
        y := Date2DMY(d, 3);
        dstStart := NthWeekdayOfMonth(y, 3, 1, 2);  // Sunday=1, 2nd Sunday in March
        dstEnd := NthWeekdayOfMonth(y, 11, 1, 1); // Sunday=1, 1st Sunday in Nov.

        // Between 2:00 AM on dstStart and 2:00 AM on dstEnd (exclusive)
        exit((d > dstStart) and (d < dstEnd));
    end;

    // Return the date of the Nth <weekday> in <month> of <year>.
    // weekday: 1=Sunday … 7=Saturday
    local procedure NthWeekdayOfMonth(year: Integer; month: Integer; weekday: Integer; n: Integer): Date
    var
        firstOfMonth: Date;
        firstWeekday: Integer;
        deltaDays: Integer;
    begin
        firstOfMonth := DMY2Date(1, month, year);
        firstWeekday := Date2DWY(firstOfMonth, 1); // 1=Sunday … 7=Saturday
        deltaDays := (weekday - firstWeekday + 7) mod 7; // days from 1st -> first target weekday
        exit(CalcDate('+' + Format(deltaDays + (n - 1) * 7) + 'D', firstOfMonth));
    end;


    var
        fullSync: Boolean;
        dataLogHandler: Codeunit PerfionDataInLogHandler;
        changeCount: Integer;
        apiHandler: Codeunit PerfionApiHandler;
        perfionDataSyncIn: Record PerfionDataSyncIn;
        currDateTime: DateTime;
        perfionConfig: Record PerfionConfig;
        logManager: Codeunit LogManager;
        lastPerfionSync: DateTime;
}