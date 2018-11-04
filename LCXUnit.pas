(*
  ************************************************************************************
  *
  * HTran.cpp - HUC Packet Transmit Tool.
  *
  * Copyright (C) 2000-2004 HUC All Rights Reserved.
  *
  * Author   : lion
  *       : lion#cnhonker.net
  *       : [url]http://www.cnhonker.com[/url]
  *       :
  * Notice: Thx to bkbll (bkbll#cnhonker.net)
  *       :
  * Date  : 2003-10-20
  *       :
  * Complie : cl HTran.cpp
  *       :
  * Usage : E:\>HTran
  *       : ======================== HUC Packet Transmit Tool V1.00 =======================
  *       : =========== Code by lion & bkbll, Welcome to http://www.cnhonker.com ==========
  *       :
  *       : [Usage of Packet Transmit:]
  *       :   HTran -<listen|tran|slave> <option> [-log logfile]
  *       :
  *       : [option:]
  *       :   -listen <ConnectPort> <TransmitPort>
  *       :   -tran   <ConnectPort> <TransmitHost> <TransmitPort>
  *       :   -slave <ConnectHost> <ConnectPort> <TransmitHost> <TransmitPort>
  *
  ************************************************************************************
  * Pascal version by adsj 2013.5.4
  ************************************************************************************
*)
unit LCXUnit;

interface

uses
  System.SysUtils, codesitelogging,
  Winapi.Windows,
  Winapi.Winsock2;

const
  VERSION = '0.01';
  TIMEOUT = 300;
  MAXSIZE = 20480;
  HOSTLEN = 40;
  CONNECTNUM = 5;
  // ERROR CODE
  EINTR = 4;
  ENOSPC = 28;

type
  pTransock = ^transock;

  transock = record
    fd1: TSocket;
    fd2: TSocket;
  end;

  //
procedure ver();

procedure usage(prog: PAnsiChar);

procedure transmitdata(data: Pointer); stdcall;

procedure getctrlc(j: Integer);

procedure closeallfd();

procedure makelog(buffer: PAnsiChar; bflength: Integer);

procedure proxy(port: Integer);

procedure bind2bind(port1, port2: Integer);

procedure bind2conn(port1: Integer; host: PAnsiChar; port2: Integer);

procedure conn2conn(host1: PAnsiChar; port1: Integer; host2: PAnsiChar;
  port2: Integer);

function testfisvalue(str: PAnsiChar): Integer;

function create_socket(): Integer;

function create_server(sockfd: Integer; port: Integer): Integer;

function client_connect(sockfd: Integer; server: PAnsiChar;
  port: Integer): Integer;

//
procedure __Main();

var
  error: Integer;
  method: Integer;
  connects: Integer;

implementation

procedure ver();
begin
  Writeln(Format
    ('==================================my lcx %s===================================',
    [VERSION]));
  Writeln('=========== Code by lion & bkbll, Welcome to http://www.cnhonker.com ===========');
end;

procedure usage(prog: PAnsiChar);
begin
  // print some sth about this app
  Writeln('[Usage of Packet Transmit:]');
  Writeln(Format(' %s -<listen|tran|slave> <option> [-log logfile]', [prog]));
  Writeln('[option:]');
  Writeln(' -listen <ConnectPort> <TransmitPort>');
  Writeln(' -tran   <ConnectPort> <TransmitHost> <TransmitPort>');
  Writeln(' -slave <ConnectHost> <ConnectPort> <TransmitHost> <TransmitPort>');
end;

procedure transmitdata(data: Pointer); stdcall;
var
  fd1, fd2: TSocket;
  psock: pTransock;
  timeset: timeval;
  readfd, writefd: fd_set;
  ret, i: Integer;
  read_in1, send_out1: array [0 .. MAXSIZE - 1] of AnsiChar;
  read_in2, send_out2: array [0 .. MAXSIZE - 1] of AnsiChar;
  read1, totalread1, send1: Integer;
  read2, totalread2, send2: Integer;
  sendcount1, sendcount2: Integer;
  maxfd: Integer;
  client1, client2: sockaddr_in;
  structsize1, structsize2: Integer;
  host1, host2: array [0 .. 19] of AnsiChar;
  port1, port2: Integer;
  tmpbuf: array [0 .. 99] of AnsiChar;
  tbfstr: AnsiString;
  //
  err, err2: Integer;
begin
  psock := pTransock(data);
  fd1 := psock^.fd1;
  fd2 := psock^.fd2;

  FillChar(host1, 20, 0);
  FillChar(host2, 20, 0);
  FillChar(tmpbuf, 100, 0);

  structsize1 := SizeOf(sockaddr);
  structsize2 := SizeOf(sockaddr);

  if getpeername(fd1, sockaddr(client1), structsize1) < 0 then
  begin
    StrCopy(@host1[0], 'fd1');
  end
  else
  begin
    StrCopy(@host1[0], inet_ntoa(client1.sin_addr));
    port1 := ntohs(client1.sin_port);
  end;

  if getpeername(fd2, sockaddr(client2), structsize2) < 0 then
  begin
    StrCopy(@host2[0], 'fd2');
  end
  else
  begin
    StrCopy(@host2, inet_ntoa(client2.sin_addr));
    port2 := ntohs(client2.sin_port);
  end;

  // printf start transmit host1:port1 <-> host2:port2
  Writeln(Format('[+] Start Transmit (%s:%d <-> %s:%d) ......',
    [host1, port1, host2, port2]));

  if fd1 > fd2 then
    maxfd := fd1 + 1
  else
    maxfd := fd2 + 1;

  FillChar(read_in1, MAXSIZE, 0);
  FillChar(read_in2, MAXSIZE, 0);
  FillChar(send_out1, MAXSIZE, 0);
  FillChar(send_out2, MAXSIZE, 0);

  timeset.tv_sec := TIMEOUT;
  timeset.tv_usec := 0;

  while True do
  begin
    FD_ZERO(readfd);
    FD_ZERO(writefd);

    _FD_SET(fd1, readfd);
    _FD_SET(fd1, writefd);
    _FD_SET(fd2, writefd);
    _FD_SET(fd2, readfd);

    ret := select(maxfd, @readfd, @writefd, nil, @timeset);
    if (ret < 0) and (h_errno <> WSAEINTR) then
    begin
      // printf select error
      Writeln('[-] Select error.');
      Break;
    end
    else if ret = 0 then
    begin
      // printf socket time out
      Writeln('[-] Socket time out.');
      Break;
    end;

    if FD_ISSET(fd1, readfd) then
    begin
      //
      if totalread1 < MAXSIZE then
      begin
        read1 := recv(fd1, read_in1, MAXSIZE - totalread1, 0);
        if (read1 = SOCKET_ERROR) or (read1 = 0) then
        begin
          // printf read fd1 data error,maybe close?
          Writeln('[-] Read fd1 data error,maybe close?');
          Break;
        end;

        CopyMemory(@send_out1[totalread1], @read_in1[0], read1);
        // sprintf(tmpbuf,"\r\nRecv %5d bytes from %s:%d\r\n", read1, host1, port1);
        tbfstr := Format(' Recv %5d bytes from %s:%d', [read1, host1, port1]);
        StrCopy(@tmpbuf, PAnsiChar(tbfstr));
        // recv read1 bytes from host1:port1
        Writeln(Format(' Recv %5d bytes %16s:%d', [read1, host1, port1]));
        totalread1 := totalread1 + read1;
        FillChar(read_in1, MAXSIZE, 0);
      end;
    end;

    if FD_ISSET(fd2, writefd) then
    begin
      err := 0;
      sendcount1 := 0;
      while totalread1 > 0 do
      begin
        send1 := send(fd2, send_out1, totalread1, 0);
        if send1 = 0 then
          Break;
        if (send1 < 0) and (h_errno <> EINTR) then
        begin
          // printf send to fd2 unknow error
          Writeln('[-] Send to fd2 unknow error.');
          err := 1;
          Break;
        end;

        if (send1 < 0) and (h_errno = ENOSPC) then
          Break;

        sendcount1 := sendcount1 + send1;
        totalread1 := totalread1 - send1;

        // printf send send1 bytes  host2 : port2
        Writeln(Format(' Send %5d bytes %16s:%d', [send1, host2, port2]));
      end;

      if err = 1 then
        Break;

      if (totalread1 > 0) and (sendcount1 > 0) then
      begin
        // move not sended data to start addr
        CopyMemory(@send_out1, @send_out1[sendcount1], totalread1);
        FillChar(send_out1[totalread1], MAXSIZE - totalread1, 0);
      end
      else
        FillChar(send_out1, MAXSIZE, 0);
    end;

    if FD_ISSET(fd2, readfd) then
    begin
      if totalread2 < MAXSIZE then
      begin
        read2 := recv(fd2, read_in2, MAXSIZE - totalread2, 0);
        if read2 = 0 then
          Break;

        if (read2 < 0) and (h_errno <> EINTR) then
        begin
          // Read fd2 data error,maybe close?
          Writeln('[-] Read fd2 data error,maybe close?');
          Break;
        end;
        CopyMemory(@send_out2[totalread2], @read_in2, read2);

        // Recv read2 bytes host2:port2
        tbfstr := Format('Recv %5d bytes from %s:%d', [read2, host2, port2]);
        StrCopy(@tmpbuf, PAnsiChar(tbfstr));
        Writeln(Format(' Recv %5d bytes %16s:%d', [read2, host2, port2]));
        // log
        //
        totalread2 := totalread2 + read2;
        FillChar(read_in2, MAXSIZE, 0);
      end;
    end;

    if FD_ISSET(fd1, writefd) then
    begin
      err2 := 0;
      sendcount2 := 0;
      while totalread2 > 0 do
      begin
        send2 := send(fd1, send_out2[sendcount2], totalread2, 0);
        if send2 = 0 then
          Break;
        if (send2 < 0) and (h_errno <> EINTR) then
        begin
          // send to fd1 unknow error.
          Writeln('[-] Send to fd1 unknow error.');
          err2 := 1;
          Break;
        end;
        if (send2 < 0) and (h_errno = ENOSPC) then
          Break;
        sendcount2 := sendcount2 + send2;
        totalread2 := totalread2 - send2;
        // Send send2 bytes host1:port1
        Writeln(Format(' Send %5d bytes %16s:%d', [send2, host1, port1]));
      end;

      if err2 = 1 then
        Break;
      if (totalread2 > 0) and (sendcount2 > 0) then
      begin
        CopyMemory(@send_out2, @send_out2[sendcount2], totalread2);
        FillChar(send_out2[totalread2], MAXSIZE - totalread2, 0);
      end
      else
        FillChar(send_out2, MAXSIZE, 0);
    end;
    Sleep(5);
  end;

  closesocket(fd1);
  closesocket(fd2);
  //
  // ok i closed the two socket.
  Writeln('[+] OK! I Closed The Two Socket.');
end;

procedure getctrlc(j: Integer);
begin
  // received  ctrl + c
  Writeln('[-] Received Ctrl+C');
  closeallfd();
  Exit;
end;

procedure closeallfd();
var
  i: Integer;
begin
  // let me exit......
  Writeln('[+] Let me exit ......');
  // fflush(stdout)
  for i := 3 to 255 do
    closesocket(i);

  // if fp<> nil then
  // begin
  // print exit
  // fclose(fp)
  // end;
  // All Right
  Writeln('[+] All Right!');
end;

procedure makelog(buffer: PAnsiChar; bflength: Integer);
begin

end;

procedure proxy(port: Integer);
begin

end;

procedure bind2bind(port1, port2: Integer);
var
  fd1, fd2, sockfd1, sockfd2: TSocket;
  client1, client2: sockaddr_in;
  size1, size2: Integer;

  hThread: THandle;
  sock: transock;
  dwThreadID: DWORD;
begin
  fd1 := create_socket();
  if (fd1) = 0 then
    Exit;
  fd2 := create_socket();
  if (fd2) = 0 then
    Exit;
  // printf listening  port1
  Writeln(Format('[+] Listen port %d!', [port1]));
  if create_server(fd1, port1) = 0 then
  begin
    closesocket(fd1);
    Exit;
  end;

  // listen ok
  Writeln('[+] Listen OK!');
  // printf listening port2
  Writeln(Format('[+] Listening port %d ......', [port2]));

  if create_server(fd2, port2) = 0 then
  begin
    closesocket(fd2);
    Exit;
  end;

  // listen ok
  Writeln('[+] Listen OK!');

  size1 := SizeOf(sockaddr);
  size2 := SizeOf(sockaddr);

  while True do
  begin
    // waiting for Client on port 1
    Writeln(Format('[+] Waiting for Client on port:%d ......', [port1]));

    sockfd1 := accept(fd1, @client1, @size1);
    if (sockfd1) < 0 then
    begin
      // accept error
      Writeln('[-] Accept1 error.');
      Continue;
    end;
    // printf accept a Client on port1
    Writeln(Format('[+] Accept a Client on port %d from %s ......',
      [port1, inet_ntoa(client1.sin_addr)]));
    // waiting another Client on port2
    Writeln(Format('[+] Waiting another Client on port:%d....', [port2]));

    sockfd2 := accept(fd2, @client2, @size2);
    if (sockfd2) < 0 then
    begin
      // accept2 error
      Writeln('[-] Accept2 error.');
      closesocket(sockfd1);
      Continue;
    end;
    // printf accept a Client on port2 ..
    Writeln(Format('[+] Accept a Client on port %d from %s',
      [port2, inet_ntoa(client2.sin_addr)]));
    // accept connect ok
    Writeln('[+] Accept Connect OK!');

    sock.fd1 := sockfd1;
    sock.fd2 := sockfd2;

    hThread := CreateThread(nil, 0, @transmitdata, @sock, 0, dwThreadID);
    if hThread <= 0 then
    begin
      TerminateThread(hThread, 0);
      Exit;
    end;
    Sleep(1000);
    // printf CreateThread OK
    Writeln('[+] CreateThread OK!');
  end;
end;

procedure bind2conn(port1: Integer; host: PAnsiChar; port2: Integer);
var
  sockfd, sockfd1, sockfd2: TSocket;
  remote: sockaddr_in;
  size: Integer;
  buffer: array [0 .. 1023] of AnsiChar;
  aStr: AnsiString;
  hThread: THandle;
  sock: transock;
  dwThreadID: DWORD;
begin
  if (port1 < 1) or (port1 > 65535) then
  begin
    // ConnectPort invalid.
    Writeln('[-] ConnectPort invalid.');
    Exit;
  end;
  if (port2 < 1) or (port2 > 65535) then
  begin
    // TransmitPort invalid.
    Writeln('[-] TransmitPort invalid.');
    Exit;
  end;

  FillChar(buffer, 1024, 0);

  sockfd := create_socket();
  if sockfd = INVALID_SOCKET then
    Exit;

  if (create_server(sockfd, port1)) = 0 then
  begin
    closesocket(sockfd);
    Exit;
  end;

  size := SizeOf(sockaddr);

  while True do
  begin
    // Waiting for Client.....
    Writeln('[+] Waiting for Client.....');
    sockfd1 := accept(sockfd, @remote, @size);
    if sockfd1 < 0 then
    begin
      // Accept error.
      Writeln('[-] Accept error.');
      Continue;
    end;

    // Accept a Client form  inet_ntoa( remote.sin_addr ) : ntohs( remote.sin_port)
    Writeln(Format('[+] Accept a Client from %s:%d ......',
      [inet_ntoa(remote.sin_addr), ntohs(remote.sin_port)]));

    sockfd2 := create_socket();
    if sockfd2 = 0 then
    begin
      closesocket(sockfd1);
      Continue;
    end;

    // make a Connection to host : port
    // fflush(stdout)
    Writeln(Format('[+] Make a Connection to %s:%d ......', [host, port2]));

    if client_connect(sockfd2, host, port2) = 0 then
    begin
      closesocket(sockfd2);
      // sprintf(buffer,'[Server]connection to host:port2')
      aStr := Format('[SERVER]connection to %s:%d error', [host, port2]);
      StrCopy(@buffer, PAnsiChar(aStr));
      send(sockfd1, buffer, StrLen(buffer), 0);
      FillChar(buffer, 1024, 0);
      closesocket(sockfd1);
      Continue;
    end;
    // printf Connect OK
    Writeln('[+] Connect OK!');
    sock.fd1 := sockfd1;
    sock.fd2 := sockfd2;

    hThread := CreateThread(nil, 0, @transmitdata, @sock, 0, dwThreadID);
    if hThread = 0 then
    begin
      TerminateThread(hThread, 0);
      Exit;
    end;
    Sleep(1000);
    // printf CreateThread OK!
    Writeln('[+] CreateThread OK!');
  end;

end;

procedure conn2conn(host1: PAnsiChar; port1: Integer; host2: PAnsiChar;
  port2: Integer);
var
  sockfd1, sockfd2: TSocket;
  hThread: THandle;
  sock: transock;
  dwThreadID: DWORD;
  fds: fd_set;
  l: Integer;
  buffer: array [0 .. MAXSIZE - 1] of AnsiChar;
begin
  while True do
  begin
    //

    sockfd1 := create_socket();
    if sockfd1 = 0 then
      Exit;
    sockfd2 := create_socket();
    if sockfd2 = 0 then
      Exit;

    // make a connection to host1:port1
    Writeln(Format('[+] Make a Connection to %s:%d....', [host1, port1]));
    // ffliush(stdout)
    if client_connect(sockfd1, host1, port1) = 0 then
    begin
      closesocket(sockfd1);
      closesocket(sockfd2);
      Continue;
    end;
    // fix by bkbll
    // if host1:port1 recved data, then connect to host2:port2
    l := 0;
    FillChar(buffer, MAXSIZE, 0);
    while True do
    begin
      FD_ZERO(fds);
      _FD_SET(sockfd1, fds);

      if select(sockfd1, @fds, nil, nil, nil) = SOCKET_ERROR then
      begin
        if h_errno = WSAEINTR then
          Continue;
        Break;
      end;

      if FD_ISSET(sockfd1, fds) then
      begin
        l := recv(sockfd1, buffer, MAXSIZE, 0);
        Break;
      end;
      Sleep(5);
    end;

    if (l <= 0) then
    begin
      // there is a error...Create a new connection.
      Writeln('[-] There is a error...Create a new connection.');
      Continue;
    end;

    while True do
    begin
      // connect ok!
      Writeln('[+] Connect OK!');
      // make a connection to host2:port2
      Writeln(Format('[+] Make a Connection to %s:%d....', [host2, port2]));
      // fflush(stdout)

      if client_connect(sockfd2, host2, port2) = 0 then
      begin
        closesocket(sockfd1);
        closesocket(sockfd2);
        Continue;
      end;

      if send(sockfd2, buffer, 1, 0) = SOCKET_ERROR then
      begin
        // send failed.
        Writeln('[-] Send failed.');
        Continue;
      end;
      l := 0;
      FillChar(buffer, 0, MAXSIZE);
      Break;
    end;

    // all connect ok!
    Writeln('[+] All Connect OK!');
    sock.fd1 := sockfd1;
    sock.fd2 := sockfd2;

    hThread := CreateThread(nil, 0, @transmitdata, @sock, 0, dwThreadID);
    if hThread = 0 then
    begin
      TerminateThread(hThread, 0);
      Exit;
    end;

    Sleep(1000);
    // printf CreateThread OK!
    Writeln('[+] CreateThread OK!');
  end;
end;

function testfisvalue(str: PAnsiChar): Integer;
begin
  if str = nil then
    Exit(0);
  if str^ = '-' then
    Exit(0);

  Exit(1);
end;

function create_socket(): Integer;
var
  sockfd: TSocket;
begin
  sockfd := socket(AF_INET, SOCK_STREAM, 0);
  if sockfd < 0 then
  begin
    Writeln('[-] Create socket error.');
    Exit(0);
  end;

  Exit(sockfd);
end;

function create_server(sockfd: Integer; port: Integer): Integer;
var
  srvaddr: sockaddr_in;
  ion: Integer;
begin
  srvaddr.sin_port := htons(port);
  srvaddr.sin_family := AF_INET;
  srvaddr.sin_addr.S_addr := htonl(INADDR_ANY);

  setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, '1', 1);

  if bind(sockfd, sockaddr(srvaddr), SizeOf(sockaddr)) < 0 then
  begin
    Writeln('[-] Socket bind error.');
    Exit(0);
  end;

  if listen(sockfd, CONNECTNUM) < 0 then
  begin
    Writeln('[-] Socket Listen error.');
    Exit(0);
  end;

  Exit(1);
end;

function client_connect(sockfd: Integer; server: PAnsiChar;
  port: Integer): Integer;
var
  cliaddr: sockaddr_in;
  host: phostent;
begin
  host := gethostbyname(server);
  if host = nil then
  begin
    Writeln(Format('[-] Gethostbyname(%s) error:%d', [server, (h_errno)]));
    Exit(0);
  end;

  cliaddr.sin_family := AF_INET;
  cliaddr.sin_port := htons(port);
  cliaddr.sin_addr := in_addr(PInAddr(host.h_addr^)^); // ?

  if connect(sockfd, sockaddr(cliaddr), SizeOf(sockaddr)) < 0 then
  begin
    Writeln(Format('[-] Connect %s error: %d', [server, h_errno]));
    Exit(0);
  end;

  Exit(1);
end;

procedure __Main();
var
  sConnectHost, sTransmitHost: array [0 .. HOSTLEN - 1] of AnsiChar;
  iConnectPort, iTransmitPort: Integer;
  wsadata: TWsaData;
begin
  ver();
  FillChar(sConnectHost, HOSTLEN, 0);
  FillChar(sTransmitHost, HOSTLEN, 0);

  WSAStartup(MakeWord(1, 1), wsadata);
  method := 0;

  if ParamCount > 2 then
  begin
    if (ParamStr(1) = '-listen') and (ParamCount >= 3) then
    begin
      iConnectPort := StrToInt(ParamStr(2));
      iTransmitPort := StrToInt(ParamStr(3));
      method := 1;
    end
    else if (ParamStr(1) = '-tran') and (ParamCount >= 4) then
    begin
      iConnectPort := StrToInt(ParamStr(2));
      StrCopy(@sTransmitHost, PAnsiChar(AnsiString(ParamStr(3))));
      iTransmitPort := StrToInt(ParamStr(4));
      method := 2;
    end
    else if (ParamStr(1) = '-slave') and (ParamCount >= 5) then
    begin
      StrCopy(@sConnectHost, PAnsiChar(AnsiString(ParamStr(2))));
      iConnectPort := StrToInt(ParamStr(3));
      StrCopy(@sTransmitHost, PAnsiChar(AnsiString(ParamStr(4))));
      iTransmitPort := StrToInt(ParamStr(5));
      method := 3;
    end;
  end;

  case method of
    1:
      bind2bind(iConnectPort, iTransmitPort);
    2:
      bind2conn(iConnectPort, sTransmitHost, iTransmitPort);
    3:
      conn2conn(sConnectHost, iConnectPort, sTransmitHost, iTransmitPort);
  else
    usage(PAnsiChar(AnsiString(ParamStr(0))));
  end;

  if method <> 0 then
  begin
    closeallfd();
  end;

  WSACleanup();
end;

end.
