pageextension 50182 WhseRcptSubform extends "Whse. Receipt Subform"
{
    layout
    {
    }
    trigger OnAfterGetRecord()
    var
        Item: Record Item;
    begin
        if Item.Get(Rec."Item No.") then begin
            if (Item.PerfionPicture = Item.PerfionPicture::Needed) or (Item.PerfionPicture = Item.PerfionPicture::"Retake Needed") then
                Rec.needPictureFlag := 'Need Picture'
            else
                Rec.needPictureFlag := '';
        end;
    end;

}