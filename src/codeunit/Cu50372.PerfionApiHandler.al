codeunit 50372 PerfionApiHandler
{
    trigger OnRun()
    var
    begin
    end;

    [TryFunction]
    procedure perfionPostRequest(var CallResponse: Text; var ErrorList: List of [Text]; Content: Text)
    var
        Client: HttpClient;
        RequestContent: HttpContent;
        ResponseMessage: HttpResponseMessage;
        ContentHeaders: HttpHeaders;
        AuthorizationValue: Text;
        token: Text;
    begin
        if initPerfion(token) then begin
            RequestContent.GetHeaders(ContentHeaders);
            ContentHeaders.Clear();
            AuthorizationValue := 'Bearer ' + token;
            Client.DefaultRequestHeaders.Add('Authorization', AuthorizationValue);
            RequestContent.WriteFrom(Content);
            ContentHeaders.Remove('Content-Type');
            ContentHeaders.Add('Content-Type', 'application/json');

            if not Client.Post(baseUrl, RequestContent, ResponseMessage) then begin
                ErrorList.Add(GetLastErrorText());
                exit;
            end;

            RequestErrorHandler(ResponseMessage, ErrorList);
            ResponseMessage.Content.ReadAs(CallResponse);
        end;
    end;

    [TryFunction]
    local procedure initPerfion(var token: Text)
    var
        Response: Text;
        ErrorList: List of [Text];
        ErrorListMsg: Text;
        responseObject: JsonObject;
        dataToken: JsonToken;
    begin
        baseUrl := 'https://abilene-api.perfioncloud.com/data';

        if not getToken(Response, ErrorList) then begin
            errorHandler.enterLog(Process::"API Handler", 'getToken', '', GetLastErrorText());
            exit;
        end;

        if ErrorList.Count > 0 then begin
            foreach ErrorListMsg in ErrorList do begin
                errorHandler.enterLog(Process::"API Handler", 'getToken', '', ErrorListMsg);
            end;
            exit;
        end;

        responseObject.ReadFrom(Response);
        responseObject.SelectToken('access_token', dataToken);
        token := dataToken.AsValue().AsText();

    end;

    [TryFunction]
    local procedure getToken(var CallResponse: Text; var ErrorList: List of [Text])
    var
        Client: HttpClient;
        RequestContent: HttpContent;
        ResponseMessage: HttpResponseMessage;
        tokenUrl: Text;

    begin
        //LOGIC - Get the token from Perfion. A token last for a period of time. When it expires a new one must get generated.
        //LOGIC - This runs every time to ensure a current token is established
        //NOTE - More info on this can be found here https://perfion.atlassian.net/wiki/spaces/PIM/pages/244330998/Authentication
        tokenUrl := 'https://abilene-api.perfioncloud.com/token?username=API&password=OXi3/3vKHtkzR4xgHNFL78uFZEH2MjsOj3qEID6eWw0=&grant_type=Password';

        //LOGIC - Run the GET call on the HttpClient. The tokenUrl is the input and the ResponseMessage is the output.
        if not Client.Get(tokenUrl, ResponseMessage) then begin
            ErrorList.Add(GetLastErrorText());
            exit;
        end;

        RequestErrorHandler(ResponseMessage, ErrorList);
        ResponseMessage.Content.ReadAs(CallResponse);
    end;

    local procedure RequestErrorHandler(ResponseMessage: HttpResponseMessage; var ErrorList: List of [Text])
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
        errorHandler: Codeunit PerfionLogHandler;
        Process: Enum PerfionProcess;

}