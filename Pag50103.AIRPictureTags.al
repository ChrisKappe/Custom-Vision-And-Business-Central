page 50103 "AIR PictureTags"
{

    PageType = List;
    SourceTable = "AIR PictureTags";
    Caption = 'AIR PictureTags';
    ApplicationArea = All;
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("TagName"; "TagName")
                {
                    ApplicationArea = All;
                }
                field("Probability"; "Probability")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

}
