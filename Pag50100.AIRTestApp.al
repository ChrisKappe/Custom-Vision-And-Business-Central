page 50100 "AIR TestApp"
{
    PageType = Card;

    actions
    {
        area(Processing)
        {
            action("Test Image from Url")
            {
                ApplicationArea = All;
                Image = TestReport;

                trigger OnAction()
                begin
                    TestAppUrlMode();
                end;
            }
            action("Test Image from Media")
            {
                ApplicationArea = All;
                Image = TestReport;

                trigger OnAction()
                begin
                    TestAppMediaMode();
                end;
            }

        }
    }

    local procedure TestAppUrlMode()
    var
        PictureToAnalyze: Record "AIR Picture-To-Analyze";
    begin
        with PictureToAnalyze do begin
            "Picture storage" := "Picture storage"::Url;
            "Picture URL" := 'http://images.fineartamerica.com/images/artworkimages/mediumlarge/1/single-red-ripe-toxic-moldy-tomato-fruit-arletta-cwalina.jpg';
            AnalyzePicture();
        end;
    end;

    local procedure TestAppMediaMode()
    var
        PictureToAnalyze: Record "AIR Picture-To-Analyze";
        item: Record Item;
    begin
        item.get('1036');
        with PictureToAnalyze do begin
            "Picture storage" := "Picture storage"::Media;
            "Picture Media GUID" := item.Picture.ITEM(item.Picture.Count());
            AnalyzePicture();
        end;
    end;


}