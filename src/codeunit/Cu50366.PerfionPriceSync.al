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
        initPerfion();

        //LOGIC - Start the Post request to get the data from Perfion
        PerfionPostRequest();

    end;



    [TryFunction]
    procedure PerfionPostRequest()
    var
        Client: HttpClient;
        RequestContent: HttpContent;
        ResponseMessage: HttpResponseMessage;
        OutputText: Text;
        ContentHeaders: HttpHeaders;
        AuthorizationValue: Text;
        AuthorizationString: Text;
        Url: Text;
        CallResponse: Text;
        Content: Text;
        ErrorList: List of [Text];
        ErrorMsg: Text;

    begin
        Content := GenerateQueryContent();
        Url := BaseUrl.TrimEnd('/');
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        AuthorizationValue := 'Bearer ' + perfionToken;
        Client.DefaultRequestHeaders.Add('Authorization', AuthorizationValue);
        RequestContent.WriteFrom(Content);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        if not Client.Post(Url, RequestContent, ResponseMessage) then begin
            ErrorHandler.logPerfionError('Get Perfion Data', GetLastErrorText());
            Error(GetLastErrorText());
            exit;
        end;

        RequestErrorHandler(ResponseMessage, ErrorList);
        if ErrorList.Count > 0 then begin
            foreach ErrorMsg in ErrorList do begin
                ErrorHandler.logPerfionError('Get Perfion Data', ErrorMsg);
                Error(ErrorMsg);
            end;
        end;

        ResponseMessage.Content.ReadAs(CallResponse);

        if ResponseMessage.IsSuccessStatusCode then
            processPerfionResponse(CallResponse)

    end;

    procedure RequestErrorHandler(ResponseMessage: HttpResponseMessage; var ErrorList: List of [Text])
    var
        Response: Text;
        JO: JsonObject;
        T1: JsonToken;
        ValueToken: JsonToken;
        i: Integer;
    begin
        ResponseMessage.Content.ReadAs(Response);
        if JO.ReadFrom(Response) then begin
            if JO.SelectToken('message', T1) then begin
                if T1.IsArray then
                    if T1.AsArray().Count > 0 then begin
                        foreach ValueToken in T1.AsArray() do ErrorList.Add('Call Error: ' + ValueToken.AsValue().AsText());
                    end;
            end;
        end
        else begin
            if jo.Keys.Count <> 0 then
                ErrorList.Add('Payload Error: Payload is not JSON Format.')
            else
                ErrorList.Add('Empty response from Perfion');
        end;
        if ErrorList.Count = 0 then
            if not ResponseMessage.IsSuccessStatusCode then begin
                ErrorList.Add('Http Status Code: ' + Format(ResponseMessage.HttpStatusCode) + ', Reason Phrase: ' + ResponseMessage.ReasonPhrase);
            end
            else if Response.Contains('<!doctype') then ErrorList.Add('Bad Response received.');
    end;

    [TryFunction]
    local procedure processPerfionResponse(response: Text)
    var
        responseObject: JsonObject;
        dataToken: JsonToken;
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
        changeCount: Integer;
        perfionPriceSync: Record PerfionPriceSync;

    begin
        changeCount := 0;
        responseObject.ReadFrom(response);
        responseObject.SelectToken('Data', dataToken);
        dataToken.SelectToken('Items', itemsToken);

        foreach itemsToken in itemsToken.AsArray() do begin
            itemsToken.SelectToken('Values', valuesToken);
            if valuesToken.AsArray().Count > 0 then begin
                valuesToken.AsArray().Get(0, valueItemToken);
                valueItemToken.SelectToken('value', itemNumToken);

                foreach valuesToken in valuesToken.AsArray() do begin
                    valuesToken.SelectToken('featureId', featureId);
                    if featureId.AsValue().AsInteger() <> 100 then begin

                        valuesToken.SelectToken('modifiedDate', itemDateModified);
                        modifiedDate := DT2Date(itemDateModified.AsValue().AsDateTime());

                        //DEVELOPER - Testing Only
                        //dateYesterday := DMY2Date(1, 4, 2024);

                        if modifiedDate > dateYesterday then begin
                            valuesToken.SelectToken('value', itemPriceToken);
                            valuesToken.SelectToken('featureName', itemPriceTypeToken);
                            updatePriceListLine(itemNumToken.AsValue().AsCode(), itemPriceToken.AsValue().AsDecimal(), itemPriceTypeToken.AsValue().AsText(), itemDateModified.AsValue().AsDateTime());
                            changeCount += 1;
                        end;
                    end;
                end;
            end
        end;
        perfionPriceSync.Get();
        perfionPriceSync.Processed := changeCount;
        perfionPriceSync.Modify();

    end;

    local procedure updatePriceListLine(itemNo: Code[20]; price: Decimal; priceGroup: Text; modified: DateTime)
    var
        priceList: Record "Price List Line";
        originalPrice: Decimal;
        perfionPriceSync: Record PerfionPriceSync;

    begin
        perfionPriceSync.Get();
        priceList.Reset();
        priceList.SetRange("Price List Code", perfionPriceSync.SalesPriceList);
        priceList.SetFilter("Product No.", itemNo);
        priceList.SetFilter("Source No.", getPriceGroup(priceGroup));
        if priceList.FindFirst() then begin
            originalPrice := priceList."Unit Price";
            priceList."Unit Price" := price;
            logHandler.LogItemUpdate(itemNo, originalPrice, price, priceList."Source No.", getLocalDateTime(modified));
            priceList.Modify();
        end;
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

        //NOTE - Add features (attributes) needed from Perfion. This is done in buildFeatures()
        jObjSelect.Add('Features', buildFeatures());

        //NOTE - Add to main inner object
        jObjQueryInner.Add('Select', jObjSelect);

        //LOGIC - Build the From Query
        jObjFrom.Add('id', 'Product');
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

    local procedure buildListPriceTypes() features: List of [Text]
    begin
        features.Add('RetailPrice');
        features.Add('Wholesale');
        features.Add('W05Calculated');
        features.Add('W1Calculated');
        features.Add('W2Calculated');
        features.Add('W3Calculated');
        features.Add('W4Calculated');
    end;

    local procedure buildFeatures(): JsonArray
    var
        features: List of [Text];
        feature: Text;
        jObject: JsonObject;
        jArray: JsonArray;

    begin
        features := buildListPriceTypes();

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
        features := buildListPriceTypes();

        foreach feature in features do begin
            jObject.Add('Clause', buildClauses(feature));
            jObject.Add('Or', jObjectEmpty);
            jArray.Add(jObject);
            Clear(jObject);
        end;

        exit(jArray);
    end;

    local procedure buildClauses(priceType: Text): JsonObject
    var
        jObjValue: JsonObject;
        jObjValueDetail: JsonObject;
        jArrValue: JsonArray;
        utcYesterday: DateTime;
        utcToday: DateTime;
        TypeHelper: Codeunit "Type Helper";
        utcTodayText: Text;

    begin
        utcYesterday := getDateYesterday();
        utcToday := TypeHelper.GetCurrUTCDateTime();

        utcTodayText := Format(utcToday, 0, '<Year4>-<Month,2>-<Day,2>');

        //NOTE - example format Perfion expects 2024-05-04 00:00:00"

        jObjValue.Add('id', priceType + '.modifiedDate');
        jObjValue.Add('operator', 'BETWEEN');
        //DEVELOPER - Testing Only
        //jArrValue.Add('2024-05-01 00:00:00');
        //jArrValue.Add('2024-05-05 23:00:00');
        jArrValue.Add(utcTodayText + ' 00:00:00');
        jArrValue.Add(utcTodayText + ' 23:00:00');
        jObjValue.Add('value', jArrValue);

        exit(jObjValue);
    end;

    local procedure getLocalDateTime(utc: DateTime): DateTime
    var
        TypeHelper: Codeunit "Type Helper";
    begin
        exit(TypeHelper.ConvertDateTimeFromUTCToTimeZone(utc, 'Central Standard Time'))
    end;

    local procedure getDateYesterday(): DateTime
    var
        UTC_DT: DateTime;
        UTC_D: Date;
        TypeHelper: Codeunit "Type Helper";
    begin
        UTC_DT := TypeHelper.GetCurrUTCDateTime();
        UTC_D := DT2Date(UTC_DT);
        dateYesterday := DMY2Date(Date2DMY(UTC_D, 1) - 1, Date2DMY(UTC_D, 2), Date2DMY(UTC_D, 3));
        exit(CreateDateTime(dateYesterday, DT2Time(UTC_DT)))
    end;

    local procedure initPerfion()
    var
        perfionConfig: Record PerfionConfig;
    begin
        //BaseUrl := 'https://abilene-api.perfioncloud.com/data';

        //LOGIC - Check that the config has been entered
        if not perfionConfig.Get() then Error('Perfion has not been configured.  Please setup using Perfion Configuration.');

        //LOGIC - get the token from Perfion
        getToken();
        perfionToken := perfionConfig."Access Token";
        BaseUrl := perfionConfig."Perfion Base URL";
        SendInventory := perfionConfig.Enabled;
    end;

    procedure getToken()
    var
        Client: HttpClient;
        RequestContent: HttpContent;
        ResponseMessage: HttpResponseMessage;
        tokenUrl: Text;
        CallResponse: Text;
        responseObject: JsonObject;
        dataToken: JsonToken;
        perfionConfig: Record PerfionConfig;

    begin
        //LOGIC - Get the token from Perfion. A token last for a period of time. When it expires a new one must get generated.
        //LOGIC - This runs every time to ensure a current token is established
        //NOTE - More info on this can be found here https://perfion.atlassian.net/wiki/spaces/PIM/pages/244330998/Authentication
        tokenUrl := 'https://abilene-api.perfioncloud.com/token?username=API&password=OXi3/3vKHtkzR4xgHNFL78uFZEH2MjsOj3qEID6eWw0=&grant_type=Password';

        //LOGIC - Run the GET call on the HttpClient. The tokenUrl is the input and the ResponseMessage is the output.
        Client.Get(tokenUrl, ResponseMessage);

        //LOGIC - Read the ResponseMessage and store in CallResponse Text var.
        ResponseMessage.Content.ReadAs(CallResponse);

        if ResponseMessage.IsSuccessStatusCode then begin
            responseObject.ReadFrom(CallResponse);
            responseObject.SelectToken('access_token', dataToken);
            perfionConfig.Get();
            perfionConfig."Access Token" := dataToken.AsValue().AsText();
            perfionConfig.Modify();
        end;

    end;

    var
        BaseURL: Text;
        perfionToken: Text;
        SendInventory: Boolean;
        WarehouseCodeList: List of [Code[10]];
        WarehouseIDList: Dictionary of [Code[10], Integer];
        dateYesterday: Date;
        errorHandler: Codeunit PerfionErrorHandler;
        logHandler: Codeunit PerfionPriceLogHandler;

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