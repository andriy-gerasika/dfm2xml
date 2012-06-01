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
  OutputWriter: TStreamWriter;
  Param: String;
  FileNames: TStringList;
  FileName: String;
  i: Integer;
begin
  if ParamCount = 0 then
  begin
    Writeln('usage: dfm2xml (folder|file.dfm)+');
  end else
  begin
    OutputStream := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE));
    try
    OutputWriter := TStreamWriter.Create(OutputStream);
    try
      OutputWriter.Write('<xml>' + sLineBreak);
      FileNames := TStringList.Create;
      try
      for i := 1 to ParamCount do
      begin
        Param := ParamStr(i);
        if DirectoryExists(Param) then
        begin
          for FileName in TDirectory.GetFiles(Param, '*.dfm', TSearchOption.soAllDirectories) do
          begin
            FileNames.Add(FileName)
          end;
        end else
        if FileExists(FileName) then
        begin
          FileNames.Add(Param);
        end;
      end;
      FileNames.Sort;
      for FileName in FileNames do
      begin
        OutputWriter.Write('<unit name="' + ChangeFileExt(ExtractFileName(FileName), '') + '">' + sLineBreak);
        ObjectBinaryToXml(FileName, OutputStream);
        OutputWriter.Write('</unit>' + sLineBreak);
      end;
      finally
        FileNames.Sort;
      end;
      OutputWriter.Write('</xml>');
    finally
      OutputWriter.Free;
    end;
    finally
      OutputStream.Free;
    end;
  end;
end.
