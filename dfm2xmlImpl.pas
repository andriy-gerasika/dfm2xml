unit dfm2xmlImpl;

interface

uses
  System.Classes;

procedure ObjectBinaryToXml(Input, Output: TStream); overload;
procedure ObjectResourceToXml(Input, Output: TStream); overload;

implementation

uses
  System.RTLConsts,
  System.TypInfo,
  System.SysUtils,
  System.StrUtils;

{ Binary to xml conversion }

procedure ObjectBinaryToXml(Input, Output: TStream);
var
  NestingLevel: Integer;
  Reader: TReader;
  Writer: TWriter;
  ObjectName, PropName: string;
  UTF8Idents: Boolean;
  MemoryStream: TMemoryStream;
  LFormatSettings: TFormatSettings;

  procedure WriteIndent;
  const
    Blanks: array[0..0] of AnsiChar = (#9); //'<tab>';
  var
    I: Integer;
  begin
    for I := 1 to NestingLevel do Writer.Write(Blanks, SizeOf(Blanks));
  end;

  procedure WriteStr(const S: RawByteString); overload;
  begin
    Writer.Write(S[1], Length(S));
  end;

  procedure WriteStr(const S: UnicodeString); overload; inline;
  begin
    WriteStr(AnsiString(S));
  end;

  procedure WriteUTF8Str(const S: string);
  var
    Ident: UTF8String;
  begin
    Ident := UTF8Encode(S);
    if not UTF8Idents and (Length(Ident) > Length(S)) then
      UTF8Idents := True;
    WriteStr(Ident);
  end;

  procedure NewLine;
  begin
    WriteStr(sLineBreak);
    WriteIndent;
  end;

  procedure ConvertValue; forward;

  procedure ConvertHeader;
  var
    ClassName: string;
    Flags: TFilerFlags;
    Position: Integer;
  begin
    Reader.ReadPrefix(Flags, Position);
    ClassName := Reader.ReadStr;
    ObjectName := Reader.ReadStr;
    WriteIndent;
    if ffInherited in Flags then
      WriteStr('<object instance="inherited"')
    else if ffInline in Flags then
      WriteStr('<object instance="inline"')
    else
      WriteStr('<object');
    if ObjectName <> '' then
    begin
      WriteStr(' name="');
      WriteUTF8Str(ObjectName);
      WriteStr('"');
    end;
    WriteStr(' class="');
    WriteUTF8Str(ClassName);
    WriteStr('"');
    if ffChildPos in Flags then
    begin
      WriteStr(' index="');
      WriteStr(IntToStr(Position));
      WriteStr('"');
    end;

    if ObjectName = '' then
      ObjectName := ClassName;  // save for error reporting

    WriteStr('>');
    WriteStr(sLineBreak);
  end;

  procedure ConvertBinary;
  const
    BytesPerLine = 32;
  var
    MultiLine: Boolean;
    I: Integer;
    Count: Longint;
    Buffer: array[0..BytesPerLine - 1] of AnsiChar;
    Text: array[0..BytesPerLine * 2 - 1] of AnsiChar;
  begin
    Reader.ReadValue;
    WriteStr('{');
    Inc(NestingLevel);
    Reader.Read(Count, SizeOf(Count));
    MultiLine := Count >= BytesPerLine;
    while Count > 0 do
    begin
      if MultiLine then NewLine;
      if Count >= 32 then I := 32 else I := Count;
      Reader.Read(Buffer, I);
      BinToHex(Buffer, Text, I);
      Writer.Write(Text, I * 2);
      Dec(Count, I);
    end;
    Dec(NestingLevel);
    WriteStr('}');
  end;

  procedure ConvertProperty; forward;

  procedure ConvertValue;
  const
    LineLength = 64;
  var
    I, J, K, L: Integer;
    S: AnsiString;
    W: UnicodeString;
    LineBreak: Boolean;
  begin
    case Reader.NextValue of
      vaList:
        begin
          Reader.ReadValue;
          WriteStr('(');
          Inc(NestingLevel);
          while not Reader.EndOfList do
          begin
            NewLine;
            ConvertValue;
          end;
          Reader.ReadListEnd;
          Dec(NestingLevel);
          WriteStr(')');
        end;
      vaInt8, vaInt16, vaInt32:
        WriteStr(IntToStr(Reader.ReadInteger));
      vaExtended, vaDouble:
        WriteStr(FloatToStrF(Reader.ReadFloat, ffFixed, 16, 18, LFormatSettings));
      vaSingle:
        WriteStr(FloatToStr(Reader.ReadSingle, LFormatSettings) + 's');
      vaCurrency:
        WriteStr(FloatToStr(Reader.ReadCurrency * 10000, LFormatSettings) + 'c');
      vaDate:
        WriteStr(FloatToStr(Reader.ReadDate, LFormatSettings) + 'd');
      vaWString, vaUTF8String:
        begin
          W := Reader.ReadWideString;
          W := ReplaceStr(W, '&', '&amp;');
          W := ReplaceStr(W, '"', '&quot;');
          W := ReplaceStr(W, '<', '&lt;');
          W := ReplaceStr(W, '>', '&gt;');
          WriteUTF8Str(W);
        end;
      vaString, vaLString:
        begin
          S := AnsiString(Reader.ReadString);
          S := AnsiReplaceStr(S, '&', '&amp;');
          S := AnsiReplaceStr(S, '"', '&quot;');
          S := AnsiReplaceStr(S, '<', '&lt;');
          S := AnsiReplaceStr(S, '>', '&gt;');
          WriteStr(S);
        end;
      vaIdent, vaFalse, vaTrue, vaNil, vaNull:
        WriteUTF8Str(Reader.ReadIdent);
      vaBinary:
        ConvertBinary;
      vaSet:
        begin
          Reader.ReadValue;
          WriteStr('[');
          I := 0;
          while True do
          begin
            S := AnsiString(Reader.ReadStr);
            if S = '' then Break;
            if I > 0 then WriteStr(', ');
            WriteStr(S);
            Inc(I);
          end;
          WriteStr(']');
        end;
      vaCollection:
        begin
          Reader.ReadValue;
          ///WriteStr('<');
          Inc(NestingLevel);
          while not Reader.EndOfList do
          begin
            NewLine;
            WriteStr('item');
            if Reader.NextValue in [vaInt8, vaInt16, vaInt32] then
            begin
              WriteStr(' [');
              ConvertValue;
              WriteStr(']');
            end;
            WriteStr(sLineBreak);
            Reader.CheckValue(vaList);
            Inc(NestingLevel);
            while not Reader.EndOfList do
              ConvertProperty;
            Reader.ReadListEnd;
            Dec(NestingLevel);
            WriteIndent;
            WriteStr('end');
          end;
          Reader.ReadListEnd;
          Dec(NestingLevel);
          ///WriteStr('>');
        end;
      vaInt64:
        WriteStr(IntToStr(Reader.ReadInt64));
    else
      raise EReadError.CreateResFmt(@sPropertyException,
        [ObjectName, DotSep, PropName, IntToStr(Ord(Reader.NextValue))]);
    end;
  end;

  procedure ConvertProperty;
  begin
    WriteIndent;
    PropName := Reader.ReadStr;  // save for error reporting
    WriteStr('<property name="');
    WriteUTF8Str(PropName);
    WriteStr('" value="');
    ConvertValue;
    WriteStr('"/>');
    WriteStr(sLineBreak);
  end;

  procedure ConvertObject;
  begin
    ConvertHeader;
    Inc(NestingLevel);
    while not Reader.EndOfList do
      ConvertProperty;
    Reader.ReadListEnd;
    while not Reader.EndOfList do
      ConvertObject;
    Reader.ReadListEnd;
    Dec(NestingLevel);
    WriteIndent;
    WriteStr('</object>' + sLineBreak);
  end;

begin
  NestingLevel := 0;
  UTF8Idents := False;
  Reader := TReader.Create(Input, 4096);
  LFormatSettings := TFormatSettings.Create('en-US'); // do not localize
  LFormatSettings.DecimalSeparator := AnsiChar('.');
  try
    MemoryStream := TMemoryStream.Create;
    try
      Writer := TWriter.Create(MemoryStream, 4096);
      try
        Reader.ReadSignature;
        ConvertObject;
      finally
        Writer.Free;
      end;
      if UTF8Idents then
        Output.Write(TEncoding.UTF8.GetPreamble[0], 3);
      Output.Write(MemoryStream.Memory^, MemoryStream.Size);
    finally
      MemoryStream.Free;
    end;
  finally
    Reader.Free;
  end;
end;

procedure ObjectResourceToXml(Input, Output: TStream);
begin
  Input.ReadResHeader;
  ObjectBinaryToXml(Input, Output);
end;

end.
