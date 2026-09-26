$urls = @(
  'https://plugins.gradle.org/m2/',
  'https://repo1.maven.org/maven2/',
  'https://libraries.minecraft.net/',
  'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json',
  'https://piston-data.mojang.com/',
  'https://services.gradle.org/distributions/',
  'https://maven.neoforged.net/releases/net/neoforged/neoforge/26.1.2.93/neoforge-26.1.2.93.pom',
  'https://maven.neoforged.net/releases/net/neoforged/moddev-gradle/',
  'https://maven.neoforged.net/releases/net/neoforged/neoforge/26.1.2.93/neoforge-26.1.2.93-userdev.jar',
  'https://codeload.github.com/neoforged/ModDevGradle/zip/refs/heads/main'
)
foreach ($u in $urls) {
  $r = curl.exe -s -o NUL -m 25 -w '%{http_code} %{size_download}' $u 2>&1
  Write-Output ("$r  <-  $u")
}
