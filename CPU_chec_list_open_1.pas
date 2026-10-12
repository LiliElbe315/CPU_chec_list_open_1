uses SysUtils,
     {$IFDEF WINDOWS}
     Windows;
     {$ENDIF}
     {$IFDEF LINUX}
     BaseUnix;
     {$ENDIF}
{$asmmode intel}
type TSMBIOSHader=packed record
        SelectType,Length:Byte;
        Handle:Word;
        end;
     PSMBIOSHeader=^TSMBIOSHader;
//1. Вспомогательная функция чтения файлов в Linux
{$IFDEF LINUX}
function ReadSysFsDmi(const FieldName: string):string;
Var F:TextFile;
    Path:string;
begin
ReadSysFsDmi:='N/A';
Path:='/sys/class/dmi/id/'+FieldName;
if FileExists(Path) then begin
                         try
                           AssignFile(F,Path);
                           Reset(F);
                           Readln(F,ReadSysFsDmi);
                           CloseFile(F);
                         except
                         ReadSysFsDmi:='Error reading';
                         end;
                         end;
end;
{$ENDIF}
//2. Структуры Win32 API для вызова GetSystemFirmwareTable
{$IFDEF WINDOWS}
Type
  TRawSMBIOSData=packed record
  Used20CallingMethod,MajorVersion,MinorVersion,DmiRevision:Byte;
  Length:Dword;
  SMBIOSTableData:array[0..0] of Byte;//Динамический массив данных
  end;
  PRawSMBIOSData=^TRawSMBIOSData;
//Импорт Win32 API функции из kernel32.dll
function GetSystemFirmwareTable(FirmwareTableProviderSignature,FirmwareTableID:Dword;pFirmwareTableBuffer:Pointer;BufferSize:Dword):Dword;stdcall;external'kernel32.dll';
const RSMB_SIGNATURE=$52534D42;
      ACPI_SIGNATURE=$49504341;
{$ENDIF}
function GetSmbiosString(HeaderPtr:PByte;StringIndex:Byte):string;
Var StrPtr:PByte;
    CurrentIdx:Byte;
    TempStr:string;
begin
GetSmbiosString:='Unknown';
if StringIndex=0 then Exit;
StrPtr:=HeaderPtr+PSMBIOSHeader(HeaderPtr)^.Length;
CurrentIdx:=1;
while (CurrentIdx<StringIndex) and (StrPtr^<>0) do begin
                                                   while StrPtr^<>0 do Inc(StrPtr);
                                                   Inc(StrPtr);
                                                   Inc(CurrentIdx);
                                                   end;
if StrPtr^<>0 then begin
                   TempStr:=PChar(StrPtr);
                   GetSmbiosString:=TempStr;
                   end;
end;
Procedure DumpACPITable(const TableSig:string);
Var Sig,BufSize:Dword;
    Buffer:PByte;
    i:integer;
    ErrCode:Cardinal;
begin
Sig:=Ord(TableSig[1]) or (Ord(TableSig[2]) shl 8) or (Ord(TableSig[3]) shl 16) or (Ord(TableSig[4]) shl 24);
Writeln(Sig);
BufSize:=GetSystemFirmwareTable(ACPI_SIGNATURE,50434146,nil,0);
ErrCode:=GetLastError;
Writeln('ErrCode: ',ErrCode,'BufSize:',BufSize);
if BufSize=0 then begin
                  Writeln('[Error] ACPI table', TableSig,' not found');
                  exit;
                  end;
GetMem(Buffer,BufSize);
if GetSystemFirmwareTable(DWORD('ACPI'),Sig,Buffer,BufSize)<>0 then begin
                                                                     Writeln('===Dump of ACPI table',TableSig,'===');
                                                                     Writeln('Length: ',BufSize,'bytes');
                                                                     {ParseSmbiosBuffer(Buffer);}
                                                                     for i:=0 to BufSize-1 do begin
                                                                                                  Write(HexStr(Buffer[i],2),' ');
                                                                                                  if (i mod 16)=15 then Writeln;
                                                                                                  end;
                                                                     end;
FreeMem(Buffer);
end;
procedure ParseSmbiosBuffer(Buffer:PRawSMBIOSData);
Var Ptr,EndPtr,VendorPtr,NamePtr:PByte;
    Header:PSMBIOSHeader;
    VendorIdx,VersionIdx,BoardVendorIdx,BoardNameIdx,i4,i5,i6,i7,i8,i9,i10,i11,i12,i13,i14,i15,i16,i17,i18,i23,i24,i26:Byte;
    MemSize,CacheCfg,MaxSizeRaw,Cap,Volt,MaxPower:Word;
    CalculatedSize:Dword;
    CL,CDI:Byte;
    i0x6:PWord;
begin
Ptr:=@Buffer^.SMBIOSTableData[0];
EndPtr:=Ptr+Buffer^.Length;
while Ptr<EndPtr do begin
                    Header:=PSMBIOSHeader(Ptr);
                    if Header^.SelectType=0 then begin
                                                 VendorIdx:=(Ptr+4)^;
                                                 VersionIdx:=(Ptr+5)^;
                                                 i8:=(ptr+8)^;
                                                 {i9:=((ptr+9)^+1)*64;}
                                                 {i10:=PQWord(ptr+10)^};
                                                 i12:=(ptr+12)^;
                                                 i14:=(ptr+14)^;
                                                 Writeln(Header^.Length);
                                                 Writeln('Вендор BIOS: ',GetSmbiosString(Ptr,VendorIdx));
                                                 Writeln('Версия BIOS: ',GetSmbiosString(Ptr,VersionIdx));
                                                 Writeln('i0x6:',HexStr(PQword(Ptr+6)^,4));
                                                 Writeln('i8:',GetSmbiosString(Ptr,i8));
                                                 Writeln('i9:',(DWORD((ptr+9)^+1))*64);
                                                 Writeln('i10:',HexStr(PQword(Ptr+10)^,16));
                                                 end;
                    if Header^.SelectType=1 then begin
                                                 Writeln('---СИСТЕМНАЯ ИНФОРМАЦИЯ (TYPE 1)---');
                                                 i4:=(ptr+4)^;
                                                 i5:=(ptr+5)^;
                                                 i6:=(ptr+6)^;
                                                 i7:=(ptr+7)^;
                                                 Writeln('ПРОИЗВОДИТЕЛЬ:',GetSmbiosString(Ptr,i4));
                                                 Writeln('ПРОДУКТ:',GetSmbiosString(Ptr,i5));
                                                 Writeln('ВЕРСИЯ:',GetSmbiosString(Ptr,i6));
                                                 Writeln('СЕРИЙНЫЙ НОМЕР:',GetSmbiosString(Ptr,i7));
                                                 if Header^.Length>=19 then begin
                                                                            Writeln('System UUID:',HexStr(PDWORD(ptr+$08)^,8),'-',HexStr(PDWORD(ptr+$0C)^,4),'-',HexStr(PDWORD(ptr+$0E)^,4),'-',HexStr(PDWORD(ptr+$10)^,2),
                                                                            HexStr(PDWORD(ptr+$11)^,2),'-',HexStr(PDWORD(ptr+$12)^,2),HexStr(PDWORD(ptr+$13)^,2),
                                                                            HexStr(PDWORD(ptr+$14)^,2),HexStr(PDWORD(ptr+$15)^,2),HexStr(PDWORD(ptr+$16)^,2),HexStr(PDWORD(ptr+$17)^,2));
                                                                            i18:=(ptr+18)^;
                                                                            case i18 of $00:Writeln('Reserved');
                                                                                        $01:Writeln('Other');
                                                                                        $02:Writeln('Unknown');
                                                                                        $03:Writeln('APM Timer');
                                                                                        $04:Writeln('Modem Ring');
                                                                                        $05:Writeln('Lan Remote (Wake-on-LAN)');
                                                                                        $06:Writeln('Power Switch');
                                                                                        $07:Writeln('PCI PME#');
                                                                                        $08:Writeln('AC Power Restored');
                                                                                        else
                                                                                        Writeln('OEM Specific(0x',HexStr(i18,2),')');
                                                                                        end;
                                                                            end;

                                                 end;
                    if Header^.SelectType=2 then begin
                                                 BoardVendorIdx:=(Ptr+4)^;
                                                 BoardNameIdx:=(Ptr+5)^;
                                                 Writeln(Header^.Length);
                                                 i6:=(ptr+6)^;
                                                 i7:=(ptr+7)^;
                                                 i8:=(ptr+8)^;
                                                 i9:=(ptr+9)^;
                                                 i10:=(ptr+10)^;
                                                 i11:=(ptr+11)^;
                                                 i12:=(ptr+12)^;
                                                 i13:=(ptr+13)^;
                                                 Writeln('Производитель ОП: ',GetSmbiosString(Ptr,BoardVendorIdx));
                                                 Writeln('Материнская Плата: ',GetSmbiosString(Ptr,BoardNameIdx));
                                                 Writeln('i6:',GetSmbiosString(Ptr,i6));
                                                 Writeln('i7:',GetSmbiosString(Ptr,i7));
                                                 Writeln('i8:',GetSmbiosString(Ptr,i8));
                                                 Writeln('i9:',HexStr(i9,2));
                                                 Writeln('i10:',GetSmbiosString(Ptr,i10));
                                                 Writeln('i11:',GetSmbiosString(Ptr,i11));
                                                 Writeln('i12:',GetSmbiosString(Ptr,i12));
                                                 Writeln('i13:',GetSmbiosString(Ptr,i13));
                                                 end;
                    if Header^.SelectType=3 then begin
                                                 Writeln('---ИНФОРМАЦИЯ О КОРПУСЕ (TYPE 3)---');
                                                 i5:=(ptr+5)^ and $7F;
                                                 i4:=(ptr+4)^;
                                                 i6:=(ptr+6)^;
                                                 i7:=(ptr+7)^;
                                                 case i5 of $03:Writeln('Decstop');
                                                            $08:Writeln('Portable');
                                                            $09:Writeln('Laptop');
                                                            $0A:Writeln('Notebook');
                                                            $0E:Writeln('Sub Notebook');
                                                            $11:Writeln('Main Server Chassis');
                                                            else
                                                            Writeln('Other/Unknown(0x',HexStr(i5,2),')');
                                                            end;
                                                 if Header^.Length>=5 then Writeln('Производитель Шасси:',GetSmbiosString(Ptr,i4));
                                                 if Header^.Length>=7 then Writeln('Версия Корпуса:',GetSmbiosString(Ptr,i6));
                                                 if Header^.Length>=8 then Writeln('Серийный номер Шасси:',GetSmbiosString(Ptr,i7));
                                                 end;
                    if Header^.SelectType=4 then begin
                                                 Writeln('---ИНФОРМАЦИЯ О ПРОЦЕССОРЕ (TYPE 4)---');
                                                 if Header^.Length>=8 then  Writeln('Vendor: ',GetSmbiosString(Ptr,(Ptr+7)^));
                                                 if Header^.Length>=17 then begin
                                                                            i4:=(ptr+4)^;
                                                                            i16:=(ptr+16)^;
                                                                            Writeln('Socket:',GetSmbiosString(Ptr,i4));
                                                                            Writeln('Model CPU:',GetSmbiosString(Ptr,i16));
                                                                            end;
                                                 if Header^.Length>=30 then begin
                                                                            Writeln('Base Path:',PWord(Ptr+28)^,' MHg');
                                                                            Writeln('Max Path:',PWord(Ptr+26)^,' MHg');
                                                                            Writeln('Path FSB:',PWord(Ptr+24)^,' MHg');
                                                                            end;
                                                 if Header^.Length>=38 then begin
                                                                            Writeln('Core Physical:',PWord(Ptr+35)^);
                                                                            Writeln('Activ Core:',PWord(Ptr+36)^);
                                                                            Writeln('Threads:',PWord(Ptr+37)^);
                                                                            end;
                                                 end;
                    if Header^.SelectType=7 then begin
                                                 Writeln('---КЭШ-ПАМЯТЬ ПРОЦЕССОРА (TYPE 7)---');
                                                 if Header^.Length>=5 then begin
                                                                           CDI:=(ptr+4)^;
                                                                           Writeln('Socket Design:',GetSmbiosString(Ptr,CDI));
                                                                           end;
                                                 if Header^.Length>=7 then begin
                                                                           CacheCfg:=Pword(ptr+5)^;
                                                                           CL:=(CacheCfg and $0007)+1;
                                                                           Writeln('Уровень кэша: L',CL);
                                                                           if (CacheCfg and (1 shl 3))<>0 then Writeln('Construction:Socketed')
                                                                           else Writeln('Construction:Solder/Internal');
                                                                           end;
                                                 if Header^.Length>=11 then begin
                                                                            MaxSizeRaw:=PWord(ptr+9)^;
                                                                            if MaxSizeRaw<>0 then begin
                                                                                                  if (MaxSizeRaw and $8000)=0 then CalculatedSize:=MaxSizeRaw
                                                                                                  else CalculatedSize:=(MaxSizeRaw and $7FFF)*64;
                                                                                                  if CalculatedSize>=1024 then Writeln('Max Volume:',CalculatedSize shr 10,'MB');
                                                                                                  end;
                                                                            end;
                                                 if Header^.Length>=15 then begin
                                                                            Write('SRAM Type: ');
                                                                            case PWord(ptr+13)^ of
                                                                            $0002:Writeln('Unknown');
                                                                            $0004:Writeln('Non-Burst');
                                                                            $0008:Writeln('Burst');
                                                                            $0010:Writeln('Pipeline Burst');
                                                                            $0020:Writeln('Synchronous');
                                                                            $0040:Writeln('Asynchronous');
                                                                            else
                                                                            Writeln('Multi-bit/Unknown(0x',HexStr(PWord(ptr+13)^,4),')');
                                                                            end;
                                                                            end;
                                                 end;
                    if Header^.SelectType=16 then begin
                                                  Writeln('===ФИЗИЧЕСКИЙ МАССИВ ОЗУ (TYPE 16)===');
                                                  if Header^.Length>=11 then begin
                                                                             if PDword(Ptr+7)^<>$80000000 then Writeln('Макс.поддерживаемый объем: ',PDWord(Ptr+7)^ shr 10,'МБ (',PDWord(Ptr+7)^ shr 20, ' ГБ)')
                                                  else if Header^.Length>=23 then Writeln('Макс.поддерживаемый объем: ',PDWord(Ptr+15)^ shr 30,' GB');
                                                  if Header^.Length>=15 then Writeln('Всего слотов на плате: ',PWord(Ptr+13)^);
                                                  end;
                                                  end;
                    if Header^.SelectType=17 then begin
                                                  Writeln('---СЛОТ ПАМЯТИ (TYPE 17)---');
                                                  {Write('HEX DUMP (+0..+15): ');
                                                  For i12:=0 to 15 do Write(HexStr((Ptr+i12)^,2),' ');}
                                                  if Header^.Length>=19 then begin
                                                                             i17:=(ptr+17)^;
                                                                             i18:=(ptr+18)^;
                                                                             Writeln('Слот (Locator):',GetSmbiosString(Ptr,i17));
                                                                             Writeln('Банк (Bank):',GetSmbiosString(Ptr,i18));
                                                                             end;
                                                  if Header^.Length>=14 then begin
                                                                             MemSize:=PWord(Ptr+12)^;
                                                                             if MemSize=0 then Writeln('Объем слота:[СЛОТ ПУСТ]')
                                                                             else if (PWord(Ptr+12)^ and $8000)<>0 then Writeln('Объем слота:',(PWord(Ptr+12)^ and $7FFF) shr 10,' MB')
                                                                             else Writeln('Объем слота: ',PWord(ptr+12)^,' MB');
                                                                             end;
                                                  if Header^.Length>=20 then begin
                                                                             Write('Тип памяти: ');
                                                                             case (ptr+19)^ of $12:Writeln('DDR2');
                                                                                               $18:Writeln('DDR3');
                                                                                               $1A:Writeln('DDR4');
                                                                                               $22:Writeln('DDR5');
                                                                                               $1B:Writeln('LPDDR3');
                                                                                               $1C:Writeln('LPDDR4');
                                                                             else
                                                                             Writeln('Другой/Unknown(0x',HexStr((Ptr+19)^,2),')');
                                                                             end;
                                                                             end;;
                                                  if Header^.Length>=23 then Writeln('(Speed):',PWord(Ptr+21)^,' МГц');
                                                  if Header^.Length>=27 then begin
                                                                             i23:=(ptr+23)^;
                                                                             i24:=(ptr+24)^;
                                                                             i26:=(ptr+26)^;
                                                                             Writeln('Производитель ОЗУ:',GetSmbiosString(Ptr,i23));
                                                                             Writeln('Серийный номер:',GetSmbiosString(Ptr,i24));
                                                                             Writeln('Part Number:',GetSmbiosString(Ptr,i26));
                                                                             end;
                                                  end;
                    if Header^.SelectType=22 then begin
                                                  Writeln('===ПОРТАТИВНАЯ БАТАРЕЯ (TYPE 22)===');
                                                  i4:=(ptr+4)^;
                                                  i5:=(ptr+5)^;
                                                  i9:=(ptr+9)^;
                                                  if Header^.Length>=5 then Writeln('Размещение/Имя:',GetSmbiosString(Ptr,i4));
                                                  if Header^.Length>=6 then Writeln('Производитель батареи:',GetSmbiosString(Ptr,i5));
                                                  if Header^.Length>=10 then begin
                                                                             case i9 of $01:Writeln('Other');
                                                                                        $02:Writeln('Unknown');
                                                                                        $03:Writeln('Lead Acid');
                                                                                        $04:Writeln('Nickel Cadmium');
                                                                                        $05:Writeln('Nickel Metal Hydride');
                                                                                        $06:Writeln('Lithium Ion (Li-Ion');
                                                                                        $07:Writeln('Lithium Polymer (Li-Po)');
                                                                             else
                                                                             Writeln('Другой/Unknown(0x',HexStr(i9,2),')');
                                                                             end;
                                                                             end;
                                                  if Header^.Length>=12 then begin
                                                                             Cap:=PWord(Ptr+10)^;
                                                                             if Cap<>0 then Writeln('Заводская емкость:',Cap,'мВт*ч');
                                                                             end;
                                                  if Header^.Length>=14 then begin
                                                                             Volt:=PWord(Ptr+12)^;
                                                                             if Volt<>0 then Writeln('Номинальное напряжение:',Volt,'мВ');
                                                                             end;
                                                  end;
                    if Header^.SelectType=39 then begin
                                                  Writeln('===ИСТОЧНИК ПИТАНИЯ (TYPE 39)===');
                                                  i5:=(ptr+5)^;
                                                  i7:=(ptr+7)^;
                                                  if Header^.Length>=6 then Writeln('Локация Источника:',GetSmbiosString(Ptr,i5));
                                                  if Header^.Length>=8 then Writeln('Model/Vendor:',GetSmbiosString(Ptr,i7));
                                                  if Header^.Length>=14 then begin
                                                                             MaxPower:=PWord(Ptr+12)^;
                                                                             if MaxPower<>$8000 then Writeln('Максимальная мощность:',MaxPower,'Вт')
                                                                             else Writeln ('Максимальная мощьность: не указана');
                                                                             end;
                                                  end;
                    Ptr:=Ptr+Header^.Length;
                    while (Ptr<EndPtr) and not ((Ptr^=0) and ((Ptr+1)^=0)) do Inc(Ptr);
                    Inc(Ptr,2);
                    end;
end;
procedure PrintMotherboardAndBiosInfo;
{$IFDEF WINDOWS}
Var BufSize:Dword;
    Buffer:PRawSMBIOSData;
{$ENDIF}
begin
Writeln('==============================================');
Writeln('СИСТЕМНАЯ ИНФОРМАЦИЯ (SMBIOS/DMI)');
Writeln('==============================================');
{$IFDEF LINUX}
Writeln('Вендор BIOS:',ReadSysFsDmi('bios_vendor'));
Writeln('Версия BIOS:',ReadSysFsDmi('bios_version'));
Writeln('Дата релиза BIOS:',ReadSysFsDmi('bios_date'));
Writeln('Производитель ОП:',ReadSysFsDmi('board_vendor'));
Writeln('Материнская плата:',ReadSysFsDmi('board_name'));
Writeln('Ревизия платы:',ReadSysFsDmi('board_version'));
{$ENDIF}
{$IFDEF WINDOWS}
BufSize:=GetSystemFirmwareTable(RSMB_SIGNATURE,0,nil,0);
if BufSize=0 then begin
                  Writeln('[Error] Не удалось получить размер таблицы SMBIOS');
                  exit;
                  end;
GetMem(Buffer,BufSize);
if GetSystemFirmwareTable(RSMB_SIGNATURE,0,Buffer,BufSize)<>0 then begin
                                                                     Writeln('Версия SMBIOS:',Buffer^.MajorVersion,'.',Buffer^.MinorVersion);
                                                                     Writeln('Размер таблиц:',Buffer^.Length,' байт');
                                                                     ParseSmbiosBuffer(Buffer);
                                                                     end;
FreeMem(Buffer);
{$ENDIF}
Writeln('==============================================');
end;
procedure DumpCPUID;
Var maxStd,maxExt,leaf,subLeaf,rEAX,rEBX,rECX,rEDX:Cardinal;
    Vendor, Brand:array [0..48] of Char;
begin
//Мфксимальный стандартный лист
FillChar(Vendor,SizeOf(Vendor),0);
FillChar(Brand,SizeOf(Brand),0);
//-------------------------------------------------------
//1. Декодирование Vendor String(EAX=0)
//-------------------------------------------------------
asm
  push ebx
  mov eax, 0
  cpuid
  mov maxStd, eax
  mov dword ptr [Vendor[0]], ebx
  mov dword ptr [Vendor[4]], edx
  mov dword ptr [Vendor[8]], ecx
  pop ebx
end;
Writeln('=====================================================');
Writeln('CPU Vendor:',string(Vendor));
//-------------------------------------------------------
//2. Декодирование Brand String(EAX=$80000002..$80000004)
//-------------------------------------------------------
asm
  push ebx
  mov eax, $80000000
  cpuid
  mov maxExt, eax
  pop ebx
end;
if maxExt>=$80000004 then begin
                          asm
                            push ebx
                            mov eax, $80000002
                            cpuid
                            mov dword ptr [Brand[0]], eax
                            mov dword ptr [Brand[4]], ebx
                            mov dword ptr [Brand[8]], ecx
                            mov dword ptr [Brand[12]], edx
                            mov eax, $80000003
                            cpuid
                            mov dword ptr [Brand[16]], eax
                            mov dword ptr [Brand[20]], ebx
                            mov dword ptr [Brand[24]], ecx
                            mov dword ptr [Brand[28]], edx
                            mov eax, $80000004
                            cpuid
                            mov dword ptr [Brand[32]], eax
                            mov dword ptr [Brand[36]], ebx
                            mov dword ptr [Brand[40]], ecx
                            mov dword ptr [Brand[44]], edx
                            pop ebx
                          end;
                          Writeln('CPU Model',Trim(string(Brand)));
                          end;
Writeln('Max standard leaf:',maxStd);
Writeln('Max extended leaf:0x',HexStr(maxExt,8));
//-------------------------------------------------------
//3. Стандартный цикл дампера с поддержкой сублистков
//-------------------------------------------------------
asm
  mov eax, 0
  cpuid
  mov maxStd, eax
end;
Writeln('Max standard leaf: ',maxStd);
For leaf:=0 to maxStd do begin
                         subLeaf:=0;
                         repeat
                            asm
                              push ebx
                              mov eax, leaf
                              mov ecx, subLeaf
                              cpuid
                              mov rEAX, eax
                              mov rEBX, ebx
                              mov rECX, ecx
                              mov rEDX, edx
                              pop ebx
                            end;
                         //Условие выхода из многостраничных листков (4,7,11,13)
                         if (SubLeaf>0) and (rEAX=0) and (rEBX=0) and (rECX=0) and (rEDX=0) then Break;
                         if (leaf=4) or (leaf=7) or (leaf=11) or (leaf=13) or (leaf=18) or (leaf=20) or (leaf=23) or (leaf=31) or (leaf=35) then
                                                                                                                                            {if leaf=7 then begin
                                                                                                                                                           rEDX:=rEDX and (1 shl 31);
                                                                                                                                                           Writeln('rEDX=',rEDX);
                                                                                                                                                           end
                                                                                                                                                           else}
                         Writeln('Leaf ',leaf:2,' [Sub ',subLeaf:2,']:EAX=',HexStr(rEAX,8),':EBX=',HexStr(rEBX,8),':ECX=',HexStr(rECX,8),':EDX=',HexStr(rEDX,8))
                         else
                         if leaf<>3 then begin
                                         if leaf<>12 then begin
                                                          Writeln('Leaf ',leaf:2,':EAX=',HexStr(rEAX,8),':EBX=',HexStr(rEBX,8),':ECX=',HexStr(rECX,8),':EDX=',HexStr(rEDX,8));
                                                          end;
                                         end;
                         if leaf=3 then begin
                                        Writeln('Leaf  3:This leaf is otsdated');
                                        end;
                         if (leaf=12) and (rEAX=0) and (rEBX=0) and (rECX=0) and (rEDX=0) then begin
                                                                                               Writeln('Leaf 12: SGX Launch Configuration / Public Key Hash:[Disabled/Unconfigured]');
                                                                                               end;
                         Inc(subLeaf);
                         //Для обычных листков делаем только 1 итерацию (subleaf 0)
                         until (leaf<>4) and (leaf<>7) and (leaf<>11) and (leaf<>13) or (subLeaf>16);
                         end;
Writeln('Max txtended leaf: ',maxExt);
leaf:=$80000000;
if maxExt>=$80000000 then begin
                          while leaf<=maxExt do begin
                                                asm
                                                  push ebx
                                                  mov eax, leaf
                                                  xor ecx, ecx
                                                  cpuid
                                                  mov rEAX, eax
                                                  mov rEBX, ebx
                                                  mov rECX, ecx
                                                  mov rEDX, edx
                                                  pop ebx
                                                end;
                                                {Writeln('Leaf ',leaf:2,':EAX=',HexStr(rEAX,8),':EBX=',HexStr(rEBX,8),':ECX=',HexStr(rECX,8),':EDX=',HexStr(rEDX,8));}
                                                if leaf=$FFFFFFFF then Break;
                                                Inc(leaf);
                                                end;
                          end;
end;
procedure InspectRegistryHardware;
{$IFDEF WINDOWS}

  procedure ReadRegString(HKeyRoot: HKey; const SubKey, ValueName:PChar; LabelName: string);
  Var Reg: HKey;
      Buf: array[0..255] of WideChar;
      BufSize: DWord;
  begin
    if RegOpenKeyExW(HKeyRoot,PWideChar(WideString(SubKey)), 0, KEY_READ, Reg) = ERROR_SUCCESS then begin
      BufSize := SizeOf(Buf);
      FillChar(Buf, SizeOf(Buf), 0);
      if RegQueryValueExW(Reg,PWideChar(WideString(ValueName)), nil, nil, @Buf[0], @BufSize) = ERROR_SUCCESS then
        Writeln(LabelName, ': ', Trim(Widestring(Buf)));
      RegCloseKey(Reg);
    end;
  end;

  procedure EnumRegistrySubKeys(HKeyRoot: HKey; const SubKey: string);
  Var Reg, SubReg: HKey;
      KeyName: array[0..255] of WideChar;
      NameSize: DWord;
      i: Integer;
  begin
    if RegOpenKeyExW(HKeyRoot,PWideChar(WideString(SubKey)), 0, KEY_READ, Reg) = ERROR_SUCCESS then begin
      i := 0;
      NameSize := SizeOf(KeyName);
      while RegEnumKeyExW(Reg, i, @KeyName[0], @NameSize, nil, nil, nil, nil) = ERROR_SUCCESS do begin
        // ╧Ёюсєхь чруы эєЄ№ тэєЄЁ№ яюфєчыр ш т√Єр∙шЄ№ Identifiers шыш Component Information
        if RegOpenKeyExW(Reg, KeyName, 0, KEY_READ, SubReg) = ERROR_SUCCESS then begin
          // ╫рёЄю яюыхчэ√х фрээ√х ыхцрЄ т ёЄЁюъют√ї ярЁрьхЄЁрї Identifier шыш Description
          ReadRegString(SubReg, '', 'Identifier', '  -> [' + WideString(KeyName) + '] ID');
          ReadRegString(SubReg, '', 'Component Information', '  -> Info');
          RegCloseKey(SubReg);
        end;
        Inc(i);
        NameSize := SizeOf(KeyName);
      end;
      RegCloseKey(Reg);
    end;
  end;
{$ENDIF}

begin
  Writeln('==============================================');
  Writeln('             (HARDWARE TREE)');
  Writeln('==============================================');
  {$IFDEF WINDOWS}
  // 1. ╤шёЄхьэр  яырЄр ш ACPI-юяшёрэш 
  Writeln('[*] Информация о материнской плате и BIOS в реестре:');
  ReadRegString(HKEY_LOCAL_MACHINE, 'HARDWARE\DESCRIPTION\System\BIOS', 'BaseBoardManufacturer', 'Производитель платы');
  ReadRegString(HKEY_LOCAL_MACHINE, 'HARDWARE\DESCRIPTION\System\BIOS', 'BaseBoardProduct', 'Модель платы');
  ReadRegString(HKEY_LOCAL_MACHINE, 'HARDWARE\DESCRIPTION\System\BIOS', 'SystemBiosVersion', 'Версия  BIOS');
  ReadRegString(HKEY_LOCAL_MACHINE, 'HARDWARE\DESCRIPTION\System\BIOS', 'SystemBiosDate', 'Дата BIOS');
  Writeln('');
  Writeln('[*] Сканирование ветки CentralProcessor (доп.параметры):');
  EnumRegistrySubKeys(HKEY_LOCAL_MACHINE, 'HARDWARE\DESCRIPTION\System\CentralProcessor');

  Writeln('');
  Writeln('[*] Сканирование шин (MultifunctionAdapter):');
  EnumRegistrySubKeys(HKEY_LOCAL_MACHINE, 'HARDWARE\DESCRIPTION\System\MultifunctionAdapter');

  {$ELSE}
  Writeln('Реестр актуален только для Windows-систем.');
  {$ENDIF}
  Writeln('==============================================');
end;
{$IFDEF WINDOWS}
procedure ScanComPortsWin32;
Var i: Integer;
    PortName: string;
    H: THandle;
begin
  Writeln('==============================================');
  Writeln('╧╬╚╤╩ ╤╬╠-╧╬╨╥╬┬ ╫┼╨┼╟ WIN32 API');
  Writeln('==============================================');
  for i := 1 to 9 do begin
    PortName := '\\.\COM' + IntToStr(i);
    // ╧Ёюсєхь юЄъЁ√Є№ яюЁЄ ё Їырурьш чряЁюёр ёЄрЄєёр, р эх яюыэюую чрїтрЄр
    H := CreateFile(PAnsiChar(AnsiString(PortName)), GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0);
    if H <> INVALID_HANDLE_VALUE then begin
      Writeln('Прпт ', PortName, ' Существует и своюоден.');
      CloseHandle(H);
    end else begin
      // ╬°шсър 5 (ERROR_ACCESS_DENIED) ючэрўрхЄ, ўЄю яюЁЄ ╤╙┘┼╤╥┬╙┼╥, эю чрэ Є фЁєушь ёюЇЄюь!
      Writeln('GetLastError=',GetLastError);
      if GetLastError = 5 then
        Writeln('Порт ', PortName, ' Существует но занят другой программой.');
    end;
  end;
  Writeln('==============================================');
end;
{$ENDIF}
procedure ReadFullResourceDescriptor(HKeyRoot: HKey; const SubKey, ValueName: string);
Var
  Reg: HKey;
  BufSize: DWord;
  DataBuffer: array of Byte;
  i: Integer;
  HexLine: string;
begin
  if RegOpenKeyExW(HKeyRoot, PWideChar(WideString(SubKey)), 0, KEY_READ, Reg) = ERROR_SUCCESS then begin
    // 1. ╙чэрхь Єюўэ√щ ЁрчьхЁ ЄЁхсєхьюую сєЇхЁр
    BufSize := 0;
    if RegQueryValueExW(Reg, PWideChar(WideString(ValueName)), nil, nil, nil, @BufSize) = ERROR_SUCCESS then begin
      if BufSize > 0 then begin
        // 2. ┬√фхы хь фшэрьшўхёъшщ сєЇхЁ яюф яюыэ√щ ЁрчьхЁ фрээ√ї
        SetLength(DataBuffer, BufSize);

        // 3. ╫шЄрхь фрээ√х т ьрёёшт срщЄют
        if RegQueryValueExW(Reg, PWideChar(WideString(ValueName)), nil, nil, @DataBuffer[0], @BufSize) = ERROR_SUCCESS then begin
          Writeln('[*] Damp Data ', ValueName, ' (Size: ', BufSize, ' byte):');

          HexLine := '';
          for i := 0 to High(DataBuffer) do begin
            HexLine := HexLine + IntToHex(DataBuffer[i], 2) + ' ';
            // ┬√тюфшь яю 16 срщЄ т ёЄЁюъє фы  ўшЄрхьюёЄш
            if (i + 1) mod 16 = 0 then begin
              Writeln('  ', HexLine);
              HexLine := '';
            end;
          end;
          // ─юяхўрЄ√трхь юёЄрЄюъ, хёыш ёЄЁюър эх ъЁрЄэр 16
          if HexLine <> '' then
            Writeln('  ', HexLine);
        end;
      end else
        Writeln('╧рЁрьхЄЁ яєёЄ.');
    end;
    RegCloseKey(Reg);
  end else
    Writeln('═х єфрыюё№ юЄъЁ√Є№ ъы■ў ЁххёЄЁр.');
end;
begin
Writeln('Hello world');
Writeln('Processor CPUID dump:');
DumpCPUID;
{PrintMotherboardAndBiosInfo;}
InspectRegistryHardware;
ReadFullResourceDescriptor(HKEY_LOCAL_MACHINE, 'HARDWARE\DESCRIPTION\System\MultifunctionAdapter\1', 'Configuration Data');
ScanComPortsWin32;
readln;
end.
