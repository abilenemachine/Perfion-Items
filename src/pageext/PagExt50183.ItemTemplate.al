pageextension 50183 ItemTemplateCard extends "Item Templ. Card"
{
    layout
    {
        addbefore(Type)
        {
            field(PerfionSync; Rec.PerfionSync)
            {
                Caption = 'Perfion Sync Status';
                ApplicationArea = All;
                ToolTip = 'Perfion Sync Status';
                Visible = true;
                Editable = true;
            }
        }
    }
}