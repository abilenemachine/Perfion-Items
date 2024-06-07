codeunit 50370 MagentoDataSync
{
    trigger OnRun()
    var

    begin


    end;

    procedure sendCoreData(itemNo: Code[20])
    begin
        initMagento(itemNo);
    end;

    local procedure UpdateMagentoCoreData(FieldName: Code[10])
    var
        Content: Text;
        OptionToken: JsonToken;
        OptionID: Integer;
        Endpoint: Text;
        ErrorList: List of [Text];
        ErrorListMsg: Text;
        CallResponse: Text;
        logHandler: Codeunit PerfionDataInLogHandler;

    begin
        if not CheckMagentoSku then begin
            magentoLogHandler.enterLog(Process::"Find Core", 'CheckMagentoSku', GetLastErrorText(), recItem."No.");
            exit;
        end;
        if not GetCoreOptionID(OptionID, OptionToken) then begin
            magentoLogHandler.enterLog(Process::"Find Core", 'GetCoreOptionID', GetLastErrorText(), recItem."No.");
            exit;
        end;
        Content := GenerateCoreContent(OptionToken, FieldName);
        Endpoint := '/rest/V1/products/options/' + Format(OptionID);

        if not CoreItemPutRequest(Endpoint, CallResponse, ErrorList, Content) then begin
            magentoLogHandler.enterLog(Process::"Update Core", 'CoreItemPutRequest', GetLastErrorText(), recItem."No.");
            logHandler.logMagentoSync(recItem."No.", 'Error');
            exit;
        end;

        if ErrorList.Count > 0 then begin
            foreach ErrorListMsg in ErrorList do begin
                magentoLogHandler.enterLog(Process::"Update Core", 'CoreItemPutRequest', ErrorListMsg, recItem."No.");
                logHandler.logMagentoSync(recItem."No.", 'Error');
            end;
            exit;
        end;

        logHandler.logMagentoSync(recItem."No.", 'True');
    end;

    local procedure DeleteMagentoCoreData()
    var
        OptionToken: JsonToken;
        OptionID: Integer;
        Endpoint: Text;
        ErrorList: List of [Text];
        CallResponse: Text;
        ErrorListMsg: Text;
        logHandler: Codeunit PerfionDataInLogHandler;
    begin
        if not GetCoreOptionID(OptionID) then exit;
        Endpoint := '/rest/V1/products/' + recItem."No." + '/options/' + Format(OptionID);

        if not CoreItemDeleteRequest(Endpoint, CallResponse, ErrorList) then begin
            magentoLogHandler.enterLog(Process::"Delete Core", 'CoreItemDeleteRequest', GetLastErrorText(), recItem."No.");
            logHandler.logMagentoSync(recItem."No.", 'Error');
            exit;
        end;

        if ErrorList.Count > 0 then begin
            foreach ErrorListMsg in ErrorList do begin
                magentoLogHandler.enterLog(Process::"Delete Core", 'CoreItemDeleteRequest', ErrorListMsg, recItem."No.");
                logHandler.logMagentoSync(recItem."No.", 'Error');
            end;
            exit;
        end;

        logHandler.logMagentoSync(recItem."No.", 'True');
    end;

    local procedure GetCoreOptionID(var OptionID: Integer; var OptionToken: JsonToken): Boolean
    var
        Endpoint: Text;
        Response: Text;
        ResponseObject: JsonObject;
        ItemsToken: JsonToken;
        ItemToken: JsonToken;
        OptionsToken: JsonToken;
        ValueToken: JsonToken;
        CoreChargeFound: Boolean;
        ErrorList: List of [Text];
        ErrorListMsg: Text;
    begin
        CoreChargeFound := false;
        Endpoint := '/rest/V1/products?searchCriteria[filterGroups][0][filters][0][field]=sku&searchCriteria[filterGroups][0][filters][0][value]=' + recItem."No." + '&searchCriteria[filterGroups][0][filters][0][conditionType]=eq';

        if not MagentoGetRequest(Endpoint, Response, ErrorList) then begin
            magentoLogHandler.enterLog(Process::"Get Core", 'GetCoreOptionID', GetLastErrorText(), recItem."No.");
            exit;
        end;

        if ErrorList.Count > 0 then begin
            foreach ErrorListMsg in ErrorList do begin
                magentoLogHandler.enterLog(Process::"Get Core", 'GetCoreOptionID', ErrorListMsg, recItem."No.");
            end;
            exit;
        end;

        ResponseObject.ReadFrom(Response);
        ResponseObject.SelectToken('items', ItemsToken);
        if ItemsToken.AsArray().Count > 0 then begin
            ItemsToken.AsArray().Get(0, ItemToken);
            ItemToken.SelectToken('options', OptionsToken);
            foreach OptionToken in OptionsToken.AsArray() do begin
                OptionToken.SelectToken('title', ValueToken);
                if ValueToken.AsValue().AsText().ToUpper() = 'CORE CHARGE' then begin
                    OptionToken.SelectToken('option_id', ValueToken);
                    OptionID := ValueToken.AsValue().AsInteger();
                    CoreChargeFound := true;
                    break;
                end;
            end;
        end;

        if not CoreChargeFound then begin
            magentoLogHandler.enterLog(Process::"Get Core", 'Not CoreChargeFound', GetLastErrorText(), recItem."No.");
            CreateCoreOption;
        end;
        exit(CoreChargeFound);
    end;

    local procedure CreateCoreOption()
    var
        JO: JsonObject;
        OptionObject: JsonObject;
        ValueArray: JsonArray;
        ValueObject: JsonObject;
        Content: Text;
        Endpoint: Text;
        ErrorList: List of [Text];
        CallResponse: Text;
        ErrorListMsg: Text;
        logHandler: Codeunit PerfionDataInLogHandler;

    begin
        OptionObject.Add('product_sku', recItem."No.");
        OptionObject.Add('is_require', true);
        OptionObject.Add('sort_order', 1);
        OptionObject.Add('title', 'Core Charge');
        OptionObject.Add('type', 'drop_down');
        ValueObject.Add('title', 'Core Charge');
        ValueObject.Add('sort_order', 0);
        ValueObject.Add('price', recItem."Core Sales Value");
        ValueObject.Add('price_type', 'fixed');
        ValueObject.Add('sku', recItem."Core Resource Name");
        ValueArray.Add(ValueObject);
        OptionObject.Add('values', ValueArray);
        JO.Add('option', OptionObject);
        Endpoint := '/rest/V1/products/options';
        Content := Format(JO);

        if not MagentoPostRequest(Endpoint, CallResponse, ErrorList, Content) then begin
            magentoLogHandler.enterLog(Process::"Update Core", 'CreateCoreOption', GetLastErrorText(), recItem."No.");
            logHandler.logMagentoSync(recItem."No.", 'Error');
            exit;
        end;

        if ErrorList.Count > 0 then begin
            foreach ErrorListMsg in ErrorList do begin
                magentoLogHandler.enterLog(Process::"Update Core", 'CreateCoreOption', ErrorListMsg, recItem."No.");
                logHandler.logMagentoSync(recItem."No.", 'Error');
            end;
            exit;
        end;

        logHandler.logMagentoSync(recItem."No.", 'True');
    end;

    local procedure CheckMagentoSku(): Boolean
    var
        Endpoint: Text;
        CallResponse: Text;
        ResponseJO: JsonObject;
        ItemsToken: JsonToken;
        ErrorList: List of [Text];
        ErrorListMsg: Text;
        logHandler: Codeunit PerfionDataInLogHandler;
    begin
        Endpoint := '/rest/V1/products?searchCriteria[filterGroups][0][filters][0][field]=sku&searchCriteria[filterGroups][0][filters][0][value]=' + recItem."No." + '&searchCriteria[filterGroups][0][filters][0][conditionType]=eq';
        if not MagentoGetRequest(Endpoint, CallResponse, ErrorList) then begin
            magentoLogHandler.enterLog(Process::"Get Core", 'CheckMagentoSku', GetLastErrorText(), recItem."No.");
            exit;
        end;

        if ErrorList.Count > 0 then begin
            foreach ErrorListMsg in ErrorList do begin
                magentoLogHandler.enterLog(Process::"Get Core", 'CheckMagentoSku', ErrorListMsg, recItem."No.");
            end;
            exit;
        end;
        ResponseJO.ReadFrom(CallResponse);
        ResponseJO.SelectToken('items', ItemsToken);
        if not (ItemsToken.AsArray().Count > 0) then begin
            exit(false);
            magentoLogHandler.enterLog(Process::"Get Core", 'CheckMagentoSku', 'Not Found on Magento', recItem."No.");
            logHandler.logMagentoSync(recItem."No.", 'Not Found');
        end;
        exit(true);
    end;

    [TryFunction]
    procedure MagentoPostRequest(Endpoint: Text; var CallResponse: Text; var ErrorList: List of [Text]; Content: Text)
    var
        Client: HttpClient;
        RequestContent: HttpContent;
        ResponseMessage: HttpResponseMessage;
        OutputText: Text;
        ContentHeaders: HttpHeaders;
        AuthorizationValue: Text;
        AuthorizationString: Text;
        Url: Text;
        ErrorMsg: Text;

    begin

        Url := baseUrl.TrimEnd('/') + '/' + Endpoint.TrimStart('/');
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        AuthorizationValue := 'Bearer ' + magentoToken;
        Client.DefaultRequestHeaders.Add('Authorization', AuthorizationValue);
        RequestContent.WriteFrom(Content);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');
        if not Client.Post(Url, RequestContent, ResponseMessage) then begin
            ErrorList.Add(GetLastErrorText());
            exit;
        end;
        RequestErrorHandler(ResponseMessage, ErrorList);
        ResponseMessage.Content.ReadAs(CallResponse);
    end;

    local procedure GenerateCoreContent(var OptionToken: JsonToken; FieldName: Code[10]): Text
    var
        JO: JsonObject;
        T1: JsonToken;
        T2: JsonToken;
        TestToken: JsonToken;
    begin
        OptionToken.SelectToken('values', T1);
        T1.AsArray().Get(0, T2);
        if FieldName = 'PRICE' then begin
            if T2.AsObject().SelectToken('price', TestToken) then
                T2.AsObject().Replace('price', recItem."Core Sales Value")
            else
                T2.AsObject().Add('price', recItem."Core Sales Value");
        end;
        if FieldName = 'SKU' then begin
            if T2.AsObject().SelectToken('sku', TestToken) then
                T2.AsObject().Replace('sku', recItem."Core Resource Name")
            else
                T2.AsObject().Add('sku', recItem."Core Resource Name");
        end;
        T1.AsArray().Set(0, T2);
        OptionToken.AsObject().Replace('values', T1.AsArray());
        JO.Add('option', OptionToken);
        exit(Format(JO));
    end;

    [TryFunction]
    procedure CoreItemPutRequest(Endpoint: Text; var CallResponse: Text; var ErrorList: List of [Text]; Content: Text)
    var
        Client: HttpClient;
        RequestContent: HttpContent;
        ResponseMessage: HttpResponseMessage;
        ContentHeaders: HttpHeaders;
        AuthorizationValue: Text;
        Url: Text;
        Response: Text;

    begin

        Url := baseUrl.TrimEnd('/') + '/' + Endpoint.TrimStart('/');
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        AuthorizationValue := 'Bearer ' + magentoToken;
        Client.DefaultRequestHeaders.Add('Authorization', AuthorizationValue);
        RequestContent.WriteFrom(Content);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        if not Client.Put(Url, RequestContent, ResponseMessage) then begin
            ErrorList.Add(GetLastErrorText());
            exit;
        end;

        RequestErrorHandler(ResponseMessage, ErrorList);
        ResponseMessage.Content.ReadAs(CallResponse);
    end;

    local procedure GetCoreOptionID(var OptionID: Integer): Boolean
    var
        Endpoint: Text;
        Response: Text;
        ResponseObject: JsonObject;
        ItemsToken: JsonToken;
        ItemToken: JsonToken;
        OptionsToken: JsonToken;
        ValueToken: JsonToken;
        CoreChargeFound: Boolean;
        OptionToken: JsonToken;
        ErrorList: List of [Text];
        ErrorListMsg: Text;
    begin
        CoreChargeFound := false;
        Endpoint := '/rest/V1/products?searchCriteria[filterGroups][0][filters][0][field]=sku&searchCriteria[filterGroups][0][filters][0][value]=' + recItem."No." + '&searchCriteria[filterGroups][0][filters][0][conditionType]=eq';

        if not MagentoGetRequest(Endpoint, Response, ErrorList) then begin
            magentoLogHandler.enterLog(Process::"Get Core", 'GetCoreOptionID', GetLastErrorText(), recItem."No.");
            exit;
        end;

        if ErrorList.Count > 0 then begin
            foreach ErrorListMsg in ErrorList do begin
                magentoLogHandler.enterLog(Process::"Get Core", 'GetCoreOptionID', ErrorListMsg, recItem."No.");
            end;
            exit;
        end;

        ResponseObject.ReadFrom(Response);
        ResponseObject.SelectToken('items', ItemsToken);
        if ItemsToken.AsArray().Count > 0 then begin
            ItemsToken.AsArray().Get(0, ItemToken);
            ItemToken.SelectToken('options', OptionsToken);
            foreach OptionToken in OptionsToken.AsArray() do begin
                OptionToken.SelectToken('title', ValueToken);
                if ValueToken.AsValue().AsText().ToUpper() = 'CORE CHARGE' then begin
                    OptionToken.SelectToken('option_id', ValueToken);
                    OptionID := ValueToken.AsValue().AsInteger();
                    CoreChargeFound := true;
                    break;
                end;
            end;
        end;
        exit(CoreChargeFound);
    end;

    [TryFunction]
    procedure CoreItemDeleteRequest(Endpoint: Text; var CallResponse: Text; var ErrorList: List of [Text])
    var
        Client: HttpClient;
        RequestContent: HttpContent;
        ResponseMessage: HttpResponseMessage;
        ContentHeaders: HttpHeaders;
        AuthorizationValue: Text;
        Url: Text;
        Response: Text;
        ErrorMsg: Text;
    begin

        Url := baseUrl.TrimEnd('/') + '/' + Endpoint.TrimStart('/');
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        AuthorizationValue := 'Bearer ' + magentoToken;
        Client.DefaultRequestHeaders.Add('Authorization', AuthorizationValue);

        if not Client.Delete(Url, ResponseMessage) then begin
            ErrorList.Add(GetLastErrorText());
            exit;
        end;

        RequestErrorHandler(ResponseMessage, ErrorList);
        ResponseMessage.Content.ReadAs(CallResponse);
    end;

    [TryFunction]
    procedure MagentoGetRequest(Endpoint: Text; var CallResponse: Text; var ErrorList: List of [Text])
    var
        Client: HttpClient;
        RequestContent: HttpContent;
        ResponseMessage: HttpResponseMessage;
        ContentHeaders: HttpHeaders;
        AuthorizationValue: Text;
        Url: Text;
    begin

        Url := baseUrl.TrimEnd('/') + '/' + Endpoint.TrimStart('/');
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        AuthorizationValue := 'Bearer ' + magentoToken;
        Client.DefaultRequestHeaders.Add('Authorization', AuthorizationValue);

        if not Client.Get(Url, ResponseMessage) then begin
            ErrorList.Add(GetLastErrorText());
            exit;
        end;
        RequestErrorHandler(ResponseMessage, ErrorList);
        ResponseMessage.Content.ReadAs(CallResponse);
    end;


    local procedure initMagento(itemNo: Code[20])
    var
        InventorySetup: Record "Inventory Setup";
    begin
        //MagentoToken := 'yom73viq08unpbgfti5fnvtanbnl8yoq';
        InventorySetup.Get();
        if (InventorySetup."Magento API Base URL" = '') or (InventorySetup."Magento API Token" = '') then Error('Please configure Magento Core Integration settings on Inventory Setup page.');
        //MagentoToken := 'ro00h6c3moekdqt9dw3yv61a3bw10q0c';
        //BaseUrl := 'https://mcstaging.abilenemachine.com/';
        magentoToken := InventorySetup."Magento API Token";
        baseUrl := InventorySetup."Magento API Base URL";

        if not recItem.Get(itemNo) then
            exit;

        if recItem."Core Sales Value" <> 0 then
            UpdateMagentoCoreData('PRICE')
        else
            DeleteMagentoCoreData()

    end;

    procedure RequestErrorHandler(ResponseMessage: HttpResponseMessage; var ErrorList: List of [Text])
    var
        Response: Text;
        JO: JsonObject;
        ValueToken: JsonToken;
    begin
        ResponseMessage.Content.ReadAs(Response);
        if JO.ReadFrom(Response) then begin
            if JO.SelectToken('message', ValueToken) then begin
                ErrorList.Add('Call Error: ' + ValueToken.AsValue().AsText());
            end;
        end;
        if ErrorList.Count = 0 then
            if not ResponseMessage.IsSuccessStatusCode then begin
                ErrorList.Add('Http Status Code: ' + Format(ResponseMessage.HttpStatusCode) + ', Reason Phrase: ' + ResponseMessage.ReasonPhrase);
            end
            else if Response.Contains('<!doctype') then ErrorList.Add('Bad Response received.');
    end;

    var
        baseUrl: Text;
        magentoToken: Text;
        recItem: Record Item;
        magentoLogHandler: Codeunit MagentoLogHandler;
        Process: Enum MagentoProcess;
}
