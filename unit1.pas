unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  FileUtil, StrUtils, process;

const
  DirRemoveList: array of string =
    ('docs', 'tests', 'test', '.github', '.idea', '.git');

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
  private

  public

  end;

  TMinifyType = (mitPHP, mitJSON);

  {TMinify = class(TThread)
    MType: TMinifyType;
    filename: string;
    constructor Create(MinifyType: TMinifyType; targetFile: string);
    procedure Execute; override;
  end;}

var
  Form1: TForm1;

implementation

{$R *.lfm}

procedure WriteLog(content: string);
begin
  Form1.Memo1.Append(content);
end;

procedure MinifyFilePHP(filelist: TStrings);
var
  output: string;
  filename: string;
  param: string;
begin
  param := '"include ''' + Application.Location + PathDelim + 'util.php'';';
  for filename in filelist do
  begin
    param := param + 'minify_php(''' + filename + ''');';
  end;
  param := param + '"';

  RunCommand('php', ['-r', param], output, [poNoConsole]);
  WriteLog(output);
end;

procedure MinifyFileJSON(filelist: TStrings);
var
  output: string;
  filename: string;
  param: string;
begin
  param := '"include ''' + Application.Location + PathDelim + 'util.php'';';
  for filename in filelist do
  begin
    param := param + 'minify_json(''' + filename + ''');';
  end;
  param := param + '"';

  RunCommand('php', ['-r', param], output, [poNoConsole]);
  WriteLog(output);
end;

procedure DeleteDirectoryCMD(const DirectoryName: string);
var
  output: string;
begin
  {$IfDef WINDOWS}
  RunCommand('cmd', ['/C', 'rmdir', '/S', '/Q', #34+DirectoryName+#34], output, [poNoConsole]);
  {$Else}
  RunCommand('rm', ['-rf', DirectoryName]);
  {$EndIf}
  WriteLog(output);
end;

{constructor TMinify.Create(MinifyType: TMinifyType; targetFile: string);
begin
  MType:=MinifyType;
  filename:=targetFile;
  FreeOnTerminate:=true;
  inherited Create(false);
end;

procedure TMinify.Execute;
begin
  case MType of
    mitJSON: MinifyFileJSON(filename);
    mitPHP: MinifyFilePHP(filename);
  end;
end;}

procedure MinifyDirectoryPHP(dir: string);
var
  FileList: TStrings;
begin
  FileList := FindAllFiles(dir, '*.php', True);
  {for path in FileList do begin
    TMinify.Create(mitPHP, path);
  end; }
  MinifyFilePHP(FileList);
  FileList.Free;
end;

procedure CleanDirUnnecessary(Dir: string);
var
  DirList: TStrings;
  path, dirname: string;
begin
  DirList := FindAllDirectories(Dir, True);
  for path in DirList do
  begin
    dirname := ExtractFileName(path);
    if dirname in DirRemoveList then
    begin
      DeleteDirectoryCMD(path);
    end;
  end;
  DirList.Free;
end;

procedure CleanFileUnnecessary(Dir: string);
var
  FileList: TStrings;
  path: string;
begin
  FileList := FindAllFiles(Dir,
    '*.md;.gitattributes;.gitignore;LICENSE;*.xml;*.yml;*.json;*.lock');
  for path in FileList do
  begin
    DeleteFile(path);
  end;
  FileList.Free;
end;

procedure MinifyFileMisc(Dir: string);
var
  FileList: TStrings;
begin
  //Minify json
  FileList := FindAllFiles(Dir, '*.json', True);
  {for path in FileList do begin
    TMinify.Create(mitJSON, path);
  end;}
  MinifyFileJSON(FileList);
  FileList.Free;

  //Minify php
  MinifyDirectoryPHP(Dir);
end;

procedure ReplaceAutoloadPath(dir: string);
var
  FileList: TStrings;
  FilePath: string;
  s: string;
  f: TextFile;
begin
  FileList := FindAllFiles(dir, '*.php');
  for FilePath in FileList do
  begin
    s:=ReadFileToString(FilePath);
    s:=ReplaceStr(s, 'vendor/autoload.php', 'autoload.phar');
    DeleteFile(FilePath);

    AssignFile(f, FilePath);
    Rewrite(f);
    Write(f, s);
    CloseFile(f);
  end;
  FileList.Free;
end;

procedure CopyNecessaryFile(dirOld, dirNew: string);
var
  PHPFileList: TStrings;
  SingleFilePath, FileRelativePath, DisallowedPathName, NewFilePath: string;
  NeedCopy: boolean;
begin
  if not DirectoryExists(dirNew) then CreateDir(dirNew);
  PHPFileList := FindAllFiles(dirOld, '*.php', True);
  for SingleFilePath in PHPFileList do
  begin
    FileRelativePath := ReplaceStr(SingleFilePath, dirOld, '');
    NeedCopy := True;
    for DisallowedPathName in DirRemoveList do
    begin
      if Pos(DisallowedPathName, FileRelativePath) = 0 then
      begin
        //没有匹配到关键词
        Continue;
      end
      else
      begin
        //匹配到关键词
        NeedCopy := False;
        Break;
      end;

    end;
    if NeedCopy then
    begin
      NewFilePath := dirNew + PathDelim + FileRelativePath;
      CopyFile(SingleFilePath, NewFilePath, [cffCreateDestDirectory], True);
    end;
  end;
  PHPFileList.Free;

end;

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
begin
  CleanDirUnnecessary(Edit1.Caption + PathDelim + 'vendor');
  CleanFileUnnecessary(Edit1.Caption + PathDelim + 'vendor');
  MinifyFileMisc(Edit1.Caption + PathDelim + 'vendor');
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  CleanDirUnnecessary(Edit1.Caption);
  CleanFileUnnecessary(Edit1.Caption);
  MinifyFileMisc(Edit1.Caption);
end;

procedure ToPhar(SrcPath, FilePath: string);
var
  output: string;
begin
  RunCommand('php', ['-r', '"include ''' + Application.Location +
    PathDelim + 'util.php'';comphar('#39 + SrcPath + #39', '#39 + FilePath + #39');'],
    output, [poNoConsole]);

end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  DeleteFile(Edit1.Caption + PathDelim + 'autoload.phar');
  ToPhar(Edit1.Caption + PathDelim + 'vendor', Edit1.Caption +
    PathDelim + 'autoload.phar');
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  DeleteDirectoryCMD(Edit1.Caption + PathDelim + 'vendor');
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  Button2Click(Self);
  Button3Click(Self);
  Button4Click(Self);
end;

procedure TForm1.Button6Click(Sender: TObject);
begin
  CopyNecessaryFile(Edit1.Caption, Edit2.Caption);
  MinifyDirectoryPHP(Edit2.Caption);
  ToPhar(Edit2.Caption + PathDelim + 'vendor', Edit2.Caption +
    PathDelim + 'autoload.phar');
  DeleteDirectoryCMD(Edit2.Caption + PathDelim + 'vendor');
  ReplaceAutoloadPath(Edit2.Caption);
end;

procedure TForm1.Button7Click(Sender: TObject);
begin
  DeleteDirectoryCMD(Edit2.Caption);
end;

end.
