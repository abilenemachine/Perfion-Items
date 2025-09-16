table 50262 "Perfion Field Sync State"
{
    Caption = 'Perfion Field Sync State';
    InherentPermissions = rimd;
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Item No."; Code[20]) { Caption = 'Item No.'; DataClassification = CustomerContent; }

        // --- User Notes state ---
        field(10; "Notes Last Outbound At"; DateTime) { Caption = 'Notes Last Outbound At'; }
        field(11; "Notes Awaiting Ack"; Boolean) { Caption = 'Notes Awaiting Ack'; }
        field(12; "Notes Last Outbound Hash"; Text[44]) { Caption = 'Notes Last Outbound Hash'; }
        field(13; "Notes Last Inbound At"; DateTime) { Caption = 'Notes Last Inbound At'; }

        // --- Applications state ---
        field(20; "Apps Last Outbound At"; DateTime) { Caption = 'Apps Last Outbound At'; }
        field(21; "Apps Awaiting Ack"; Boolean) { Caption = 'Apps Awaiting Ack'; }
        field(22; "Apps Last Outbound Hash"; Text[44]) { Caption = 'Apps Last Outbound Hash'; }
        field(23; "Apps Last Inbound At"; DateTime) { Caption = 'Apps Last Inbound At'; }
    }

    keys
    {
        key(PK; "Item No.") { Clustered = true; }
    }
}
