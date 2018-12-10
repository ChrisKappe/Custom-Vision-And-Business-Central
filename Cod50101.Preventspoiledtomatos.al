codeunit 50101 "AIR Prevent spoiled tomatos"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnAfterTestPurchLine', '', true, true)]
    local procedure CheckIfSpoiledTomato(PurchLine: Record "Purchase Line")
    var
        CustomVision: Codeunit "AIR Custom Vision";
        ResultTags: Record "AIR PictureTags" temporary;
        Item: Record Item;
        PictureToAnalyze: Record "AIR Picture-To-Analyze";
    begin
        If PurchLine.Type <> PurchLine.Type::Item then
            exit;

        if PurchLine."No." = '' then
            exit;

        item.get(PurchLine."No.");

        PictureToAnalyze."Picture storage" := PictureToAnalyze."Picture storage"::Media;
        PictureToAnalyze."Picture Media GUID" := item.Picture.ITEM(item.Picture.Count());

        CustomVision.Analyze(PictureToAnalyze, ResultTags);

        ResultTags.Reset();
        ResultTags.SetFilter(TagName, 'spoiled tomato');
        ResultTags.SetRange(Probability, 0.8, 1);
        if ResultTags.FindFirst() then
            Error('You have spolied tomatos. Please remove them from Purchase order and Try again.');

    end;

}