pageextension 50180 PerfionItemCard extends "Item Card"
{
    layout
    {
        addafter(Blocked)
        {
            field(PerfionSync; Rec.PerfionSync)
            {
                ApplicationArea = All;
                ToolTip = 'Indicates the synchronization status with Perfion.';
                Visible = true;
                Editable = IsEditable;
            }
        }
        addbefore(PictureInstructions)
        {
            field(PerfionPicture; Rec.PerfionPicture)
            {
                ApplicationArea = All;
                ToolTip = 'Indicates the picture status with Perfion.';
                Visible = true;
                Editable = IsEditable;
            }
        }

    }

    var
        IsEditable: Boolean;

    trigger OnOpenPage()
    begin
        if UserId in ['TJROELOFSEN', 'ABAKER', 'BCOCHRAN', 'WMARKLEY', 'HDEVINE', 'PMYLES', 'SSHOLTZ'] then
            IsEditable := true
        else
            IsEditable := false;
    end;

}
