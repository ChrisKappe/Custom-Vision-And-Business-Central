codeunit 50100 "AIR Custom Vision"
{
    procedure Analyze(var PictureToAnalyze: Record "AIR Picture-To-Analyze" temporary; var PictureTags: Record "AIR PictureTags" temporary)
    var
        Handled: Boolean;
    begin
        OnBeforeAnalyze(Handled, PictureToAnalyze);

        DoAnalyze(Handled, PictureToAnalyze, PictureTags);

        OnAfterAnalyze(PictureToAnalyze, PictureTags);
    end;

    local procedure DoAnalyze(var Handled: Boolean; var PictureToAnalyze: Record "AIR Picture-To-Analyze" temporary; var PictureTags: Record "AIR PictureTags" temporary);
    var
        AuthorizationKey: Text;
    begin
        IF Handled THEN
            EXIT;

        GetTagsFromAzureCustomVisionApi(PictureToAnalyze, PictureTags);
    end;

    local procedure GetBaseURLForCustomVisionServiceIfYouHavePictureURL(): Text
    var
    begin
        exit('https://southcentralus.api.cognitive.microsoft.com/customvision/v2.0/Prediction/656b204c-17f1-4e95-b2aa-dc17f4038688/url')
    end;

    local procedure GetBaseURLForCustomVisionServiceIfYouHavePictureFile(): Text
    var
    begin
        exit('https://southcentralus.api.cognitive.microsoft.com/customvision/v2.0/Prediction/656b204c-17f1-4e95-b2aa-dc17f4038688/image')
    end;

    local procedure GetPredictionKey(): Text
    begin
        exit('2ed931400ce3483a9b724adb2489277a');
    end;

    local procedure GetTagsFromAzureCustomVisionApi(var PictureToAnalyze: Record "AIR Picture-To-Analyze" temporary; var PictureTags: Record "AIR PictureTags" temporary);
    var
        RequestMessage: HttpRequestMessage;
        ContentHeaders: HttpHeaders;
        HttpContent: HttpContent;
        HttpClient: HttpClient;
        ResponseMessage: HttpResponseMessage;

        textvalue: Text;
    begin

        AddRequestBody(HttpContent, PictureToAnalyze);

        HttpContent.GetHeaders(ContentHeaders);

        ContentHeaders.Clear();
        ContentHeaders.Add('Content-type', GetContentType(PictureToAnalyze));
        RequestMessage.Content(HttpContent);

        RequestMessage.SetRequestUri(GetUriForCustomVisionService(PictureToAnalyze));
        RequestMessage.Method := 'POST';

        HttpClient.DefaultRequestHeaders.Add('Prediction-Key', GetPredictionKey());

        HttpClient.Send(RequestMessage, ResponseMessage);

        if not ResponseMessage.IsSuccessStatusCode then
            error('The web service returned an error message:\\' +
                  'Status code: %1\' +
                  'Description: %2',
                  ResponseMessage.HttpStatusCode,
                  ResponseMessage.ReasonPhrase);

        HttpContent := ResponseMessage.Content;

        GetPictureTagsFromJSon(HttpContent, PictureTags);
    end;

    local procedure GetUriForCustomVisionService(var PictureToAnalyze: Record "AIR Picture-To-Analyze" temporary): Text
    var
    begin
        case PictureToAnalyze."Picture storage" of
            PictureToAnalyze."Picture storage"::Url:
                exit(GetBaseURLForCustomVisionServiceIfYouHavePictureURL());
            PictureToAnalyze."Picture storage"::Media:
                exit(GetBaseURLForCustomVisionServiceIfYouHavePictureFile());
            PictureToAnalyze."Picture storage"::BlobField:
                exit(GetBaseURLForCustomVisionServiceIfYouHavePictureFile());
        end;
    end;

    local procedure GetContentType(var PictureToAnalyze: Record "AIR Picture-To-Analyze" temporary): Text
    begin
        case PictureToAnalyze."Picture storage" of
            PictureToAnalyze."Picture storage"::Url:
                exit('application/json');
            PictureToAnalyze."Picture storage"::Media:
                exit('application/octet-stream');
            PictureToAnalyze."Picture storage"::BlobField:
                exit('application/octet-stream');
        end;
    end;

    local procedure AddRequestBody(var HttpContent: HttpContent; var PictureToAnalyze: Record "AIR Picture-To-Analyze" temporary)
    var
    begin
        case PictureToAnalyze."Picture storage" of
            PictureToAnalyze."Picture storage"::Url:
                HttpContent.WriteFrom(CreateTextRequestBodyToAnalyze(PictureToAnalyze));
            PictureToAnalyze."Picture storage"::Media:
                CreateStreamRequestBodyToAnalyze(PictureToAnalyze, HttpContent);
        end;

    end;

    local procedure CreateTextRequestBodyToAnalyze(var PictureToAnalyze: Record "AIR Picture-To-Analyze"): Text
    var
        RJsonObj: JsonObject;
        RJsonArr: JsonArray;
        RequestBodyConvertedToTxt: Text;
    begin
        if PictureToAnalyze."Picture storage" <> PictureToAnalyze."Picture storage"::Url then
            exit('');

        RJsonObj.Add('Url', PictureToAnalyze."Picture URL");
        RJsonObj.WriteTo(RequestBodyConvertedToTxt);
        Exit(RequestBodyConvertedToTxt);
    end;

    local procedure CreateStreamRequestBodyToAnalyze(var PictureToAnalyze: Record "AIR Picture-To-Analyze"; var HttpContent: HttpContent)
    var
        TenantMedia: Record "Tenant Media";
        PictureInStream: InStream;

        PictureInTextFormat: Text;
    begin
        if PictureToAnalyze."Picture storage" <> PictureToAnalyze."Picture storage"::Media then
            exit;

        if not TenantMedia.Get(PictureToAnalyze."Picture Media GUID") then
            exit;

        TenantMedia.CalcFields(Content);
        if TenantMedia.Content.HasValue() then begin
            Clear(PictureInStream);
            TenantMedia.Content.CreateInStream(PictureInStream);

            HttpContent.WriteFrom(PictureInStream);
            HttpContent.ReadAs(PictureInTextFormat);
        end;
    end;

    local procedure GetPictureTagsFromJson(HttpContent: HttpContent; var PictureTags: Record "AIR PictureTags" temporary)
    var
        ContentInTextFormat: Text;
        JsonArray: JsonArray;
        JsonToken: JsonToken;
        JsonObject: JsonObject;
        predictionsToken: JsonToken;
        ResultTxt: Text;
        RequestGuid: Guid;
        i: Integer;
    begin
        PictureTags.DeleteAll();
        RequestGuid := CreateGuid();

        HttpContent.ReadAs(ContentInTextFormat);
        JsonToken.ReadFrom(ContentInTextFormat);
        JsonToken.SelectToken('predictions', predictionsToken);
        predictionsToken.WriteTo(ContentInTextFormat);

        If not JsonArray.ReadFrom(ContentInTextFormat) then
            error('Invalid response, expected an JSON array as root object');

        for i := 0 to JsonArray.Count - 1 do begin
            JsonArray.Get(i, JsonToken);
            JsonObject := JsonToken.AsObject;

            WITH PictureTags do begin
                Init();
                "Request GUID" := RequestGuid;
                TagID := GetJsonValueAsText(JsonObject, 'tagId');
                TagName := GetJsonValueAsText(JsonObject, 'tagName');
                Probability := GetJsonValueAsDecimal(JsonObject, 'probability');
                Insert();
            end;
        end;
    end;

    procedure GetJsonValueAsText(var JsonObject: JsonObject; Property: text) Value: Text;
    var
        JsonValue: JsonValue;
    begin
        if not GetJsonValue(JsonObject, Property, JsonValue) then
            EXIT;
        Value := JsonValue.AsText;
    end;

    procedure GetJsonValueAsDecimal(var JsonObject: JsonObject; Property: text) Value: Decimal;
    var
        JsonValue: JsonValue;
    begin
        if not GetJsonValue(JsonObject, Property, JsonValue) then
            EXIT;
        Value := JsonValue.AsDecimal;
    end;

    local procedure GetJsonValue(var JsonObject: JsonObject; Property: text; var JsonValue: JsonValue): Boolean;
    var
        JsonToken: JsonToken;
    begin
        if not JsonObject.Get(Property, JsonToken) then
            exit;
        JsonValue := JsonToken.AsValue;
        Exit(true);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeAnalyze(var Handled: Boolean; var PictureToAnalyze: Record "AIR Picture-To-Analyze" temporary);
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterAnalyze(var PictureToAnalyze: Record "AIR Picture-To-Analyze" temporary; var PictureTags: Record "AIR PictureTags" temporary);
    begin
    end;
}