codeunit 50376 "PerfionSyncStateMgt"
{
    SingleInstance = false;

    procedure GetOrCreate(var State: Record "Perfion Field Sync State"; ItemNo: Code[20])
    begin
        if not State.Get(ItemNo) then begin
            State.Init();
            State."Item No." := ItemNo;
            State.Insert();
        end;
    end;

    procedure TextHash(Value: Text): Text[44]
    var
        Crypto: Codeunit "Cryptography Management";
        HashAlg: Option MD5,SHA1,SHA256,SHA384,SHA512;
        CleanValue: Text;
    begin
        CleanValue := DelChr(Value, '<>', ' '); // strips spaces from both ends
        HashAlg := HashAlg::SHA1;               // choose SHA1
        exit(Crypto.GenerateHashAsBase64String(CleanValue, HashAlg)); // Base64 result
    end;

    procedure WasFieldModifiedAfterCursor(ItemNo: Code[20]; FieldNo: Integer; Cursor: DateTime): Boolean
    var
        CLE: Record "Change Log Entry";
        AdjCursor: DateTime;
    begin
        if Cursor = 0DT then
            exit(WasFieldEverModified(ItemNo, FieldNo));

        AdjCursor := Cursor + 1000; // +1s before checking Change Log

        CLE.Reset();
        CLE.SetRange("Table No.", Database::Item);
        CLE.SetRange("Field No.", FieldNo);
        CLE.SetRange("Primary Key Field 1 Value", ItemNo);
        CLE.SetFilter("Date and Time", '>%1', AdjCursor);
        exit(not CLE.IsEmpty());
    end;

    local procedure WasFieldEverModified(ItemNo: Code[20]; FieldNo: Integer): Boolean
    var
        CLE: Record "Change Log Entry";
    begin
        CLE.Reset();
        CLE.SetRange("Table No.", Database::Item);
        CLE.SetRange("Field No.", FieldNo);
        CLE.SetRange("Primary Key Field 1 Value", ItemNo);
        exit(not CLE.IsEmpty());
    end;
}
