# Minimal Minecraft RCON client (dot-source it). Needs $Password set before Connect-Rcon.

function Send-RconPacket($stream, [int]$id, [int]$type, [string]$body) {
    $payload = [Text.Encoding]::UTF8.GetBytes($body)
    $len = 4 + 4 + $payload.Length + 2
    $buf = New-Object byte[] (4 + $len)
    [BitConverter]::GetBytes([int]$len).CopyTo($buf, 0)
    [BitConverter]::GetBytes($id).CopyTo($buf, 4)
    [BitConverter]::GetBytes($type).CopyTo($buf, 8)
    $payload.CopyTo($buf, 12)
    $stream.Write($buf, 0, $buf.Length)
}

function Read-Exact($stream, [int]$count) {
    $buf = New-Object byte[] $count
    $read = 0
    while ($read -lt $count) {
        $n = $stream.Read($buf, $read, $count - $read)
        if ($n -le 0) { throw 'RCON connection closed' }
        $read += $n
    }
    $buf
}

function Read-RconPacket($stream) {
    $len = [BitConverter]::ToInt32((Read-Exact $stream 4), 0)
    $data = Read-Exact $stream $len
    @{
        Id   = [BitConverter]::ToInt32($data, 0)
        Type = [BitConverter]::ToInt32($data, 4)
        Body = [Text.Encoding]::UTF8.GetString($data, 8, $len - 10)
    }
}

function Connect-Rcon([int]$port) {
    $client = New-Object Net.Sockets.TcpClient
    $client.ReceiveTimeout = 5000
    $client.SendTimeout = 5000
    $client.Connect('127.0.0.1', $port)
    $stream = $client.GetStream()
    Send-RconPacket $stream 1 3 $Password
    $resp = Read-RconPacket $stream
    if ($resp.Id -eq -1) { $client.Close(); throw "RCON auth failed on port $port" }
    @{ Client = $client; Stream = $stream }
}

function Invoke-Rcon($conn, [string]$cmd) {
    Send-RconPacket $conn.Stream 2 2 $cmd
    # Strip Minecraft color codes
    (Read-RconPacket $conn.Stream).Body -replace '§.', ''
}

function Get-Num([string]$text, [string]$pattern) {
    $m = [regex]::Match($text, $pattern)
    if ($m.Success) { [double]::Parse($m.Groups[1].Value.Replace(',', '.'), [Globalization.CultureInfo]::InvariantCulture) } else { $null }
}
