program dfm2xml;

{$APPTYPE CONSOLE}

{$IF CompilerVersion >= 21.0}
  {$WEAKLINKRTTI ON}
  {$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$IFEND}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Winapi.Windows,
  dfm2xmlImpl in 'dfm2xmlImpl.pas';

procedure ObjectBinaryToXml(const FileName: String; OutputStream: TStream); overload;
var
  InputStream: TStream;
  MemoryStream: TMemoryStream;
begin
  InputStream := TFileStream.Create(FileName, fmOpenRead);
  try
    case TestStreamFormat(InputStream) of
      sofText, sofUTF8Text:
      begin
        MemoryStream := TMemoryStream.Create;
        try
          ObjectTextToBinary(InputStream, MemoryStream);
          MemoryStream.Position := 0;
          ObjectBinaryToXml(MemoryStream, OutputStream);
        finally
          MemoryStream.Free;
        end;
      end;
      else
        assert(false);
    end;
  finally
    InputStream.Free;
  end;
end;

var
  OutputStream: TStream;
  Param: String;
  FileName: String;
  i: Integer;
begin
  if ParamCount = 0 then
  begin
    Writeln('usage: dfm2xml (folder|file.dfm)+');
  end else
  begin
    Writeln('<xml>');
    Flush(Output);
    OutputStream := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE));
    try
      for i := 1 to ParamCount do
      begin
        Param := ParamStr(i);
        if TFile.Exists(Param) then
        begin
          ObjectBinaryToXml(Param, OutputStream);
        end else
        if TDirectory.Exists(Param) then
        begin
          for FileName in TDirectory.GetFiles(Param, '*.dfm', TSearchOption.soAllDirectories) do
          begin
            ObjectBinaryToXml(FileName, OutputStream);
          end;
        end;
      end;
    finally
      OutputStream.Free;
    end;
    Writeln('</xml>');
    Flush(Output);
  end;

end.
