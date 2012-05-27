program dfm2xml;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  dfm2xmlImpl in 'dfm2xmlImpl.pas';

var
  InputStream: TStream;
  OutputStream: TStream;
  MemoryStream: TMemoryStream;
begin
  InputStream := TFileStream.Create('IndieVolume.GUI.AppSettingDialog.dfm', fmOpenRead);
  try
    OutputStream := TFileStream.Create('IndieVolume.GUI.AppSettingDialog.xml', fmCreate);
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
      OutputStream.Free;
    end;
  finally
    InputStream.Free;
  end;
end.
