$hosts = @('services.gradle.org', 'maven.neoforged.net', 'repo1.maven.org', 'plugins.gradle.org', 'piston-meta.mojang.com')
foreach ($h in $hosts) {
  try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $tcp.Connect($h, 443)
    $cb = [System.Net.Security.RemoteCertificateValidationCallback] { param($s, $c, $ch, $e) return $true }
    $ssl = New-Object System.Net.Security.SslStream($tcp.GetStream(), $false, $cb)
    $ssl.AuthenticateAsClient($h)
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($ssl.RemoteCertificate)
    Write-Output ("### $h")
    $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
    $chain.ChainPolicy.RevocationMode = 'NoCheck'
    [void]$chain.Build($cert)
    foreach ($el in $chain.ChainElements) {
      Write-Output ('    subject : ' + $el.Certificate.Subject)
      Write-Output ('    issuer  : ' + $el.Certificate.Issuer)
      Write-Output ('    thumb   : ' + $el.Certificate.Thumbprint)
      Write-Output ''
    }
    $ssl.Close(); $tcp.Close()
  } catch {
    Write-Output ("### $h  ERROR: " + $_.Exception.Message)
  }
}
