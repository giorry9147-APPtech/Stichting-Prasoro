param(
    [string]$RootUrl = "https://stichtingprasoro.com/",
    [string]$OutputDir = "."
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    Write-Host "[mirror] $Message"
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Normalize-RootUrl {
    param([string]$Url)
    if (-not $Url.EndsWith('/')) {
        return "$Url/"
    }
    return $Url
}

function Get-UrlContent {
    param([string]$Url)
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 60
        return $resp.Content
    }
    catch {
        throw "Kon URL niet ophalen: $Url - $($_.Exception.Message)"
    }
}

function Try-Get-UrlContent {
    param([string]$Url)
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 60
        return @{ Success = $true; Content = $resp.Content; StatusCode = [int]$resp.StatusCode }
    }
    catch {
        $status = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $status = [int]$_.Exception.Response.StatusCode
        }
        return @{ Success = $false; Content = $null; StatusCode = $status; Error = $_.Exception.Message }
    }
}

function Resolve-SitemapUrl {
    param([string]$Root)
    $candidates = @(
        "$Root" + "sitemap.xml",
        "$Root" + "sitemap_index.xml",
        "$Root" + "wp-sitemap.xml"
    )

    foreach ($candidate in $candidates) {
        $result = Try-Get-UrlContent -Url $candidate
        if ($result.Success -and $result.Content -match "<sitemapindex|<urlset|XML Sitemap") {
            return @{ Url = $candidate; Content = $result.Content }
        }
    }

    throw "Geen sitemap gevonden op standaardlocaties."
}

function Get-AbsoluteUrl {
    param(
        [string]$MaybeUrl,
        [System.Uri]$BaseUri
    )

    if ([string]::IsNullOrWhiteSpace($MaybeUrl)) { return $null }
    $value = $MaybeUrl.Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($value)) { return $null }

    if ($value.StartsWith('data:', [System.StringComparison]::OrdinalIgnoreCase)) { return $null }
    if ($value.StartsWith('javascript:', [System.StringComparison]::OrdinalIgnoreCase)) { return $null }
    if ($value.StartsWith('#')) { return $null }

    try {
        if ([System.Uri]::IsWellFormedUriString($value, [System.UriKind]::Absolute)) {
            return ([System.Uri]$value).AbsoluteUri
        }

        if ($value.StartsWith('//')) {
            return "$($BaseUri.Scheme):$value"
        }

        $abs = [System.Uri]::new($BaseUri, $value)
        return $abs.AbsoluteUri
    }
    catch {
        return $null
    }
}

function Get-LocalPathForPage {
    param(
        [System.Uri]$Url,
        [string]$BaseDir
    )

    $path = $Url.AbsolutePath
    if ([string]::IsNullOrWhiteSpace($path) -or $path -eq '/') {
        return (Join-Path $BaseDir 'index.html')
    }

    $trimmed = $path.Trim('/')
    $segments = $trimmed.Split('/') | Where-Object { $_ -ne '' }
    $dirPath = $BaseDir
    foreach ($seg in $segments) {
        $safe = [System.Uri]::UnescapeDataString($seg)
        $dirPath = Join-Path $dirPath $safe
    }

    Ensure-Directory -Path $dirPath
    return (Join-Path $dirPath 'index.html')
}

function Get-LocalPathForAsset {
    param(
        [System.Uri]$Url,
        [string]$BaseDir
    )

    $path = $Url.AbsolutePath
    if ([string]::IsNullOrWhiteSpace($path) -or $path -eq '/') {
        return $null
    }

    $trimmed = $path.Trim('/')
    if ([string]::IsNullOrWhiteSpace($trimmed)) { return $null }

    $segments = $trimmed.Split('/') | Where-Object { $_ -ne '' }
    $filePath = $BaseDir

    for ($i = 0; $i -lt $segments.Count; $i++) {
        $segment = [System.Uri]::UnescapeDataString($segments[$i])
        if ($i -lt $segments.Count - 1) {
            $filePath = Join-Path $filePath $segment
            Ensure-Directory -Path $filePath
        }
        else {
            $name = $segment
            if ([string]::IsNullOrWhiteSpace([System.IO.Path]::GetExtension($name))) {
                $name = "$name.bin"
            }
            $filePath = Join-Path $filePath $name
        }
    }

    return $filePath
}

function Inject-BaseTag {
    param(
        [string]$Html,
        [string]$Domain
    )

    if ($Html -match '<head[^>]*>') {
        $replacement = "<head`$1>`n<base href=`"https://$Domain/`">"
        $updated = [regex]::Replace($Html, '<head([^>]*)>', $replacement, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        return $updated
    }

    return "<head><base href=`"https://$Domain/`"></head>`n$Html"
}

function Extract-UrlsFromText {
    param(
        [string]$Text,
        [System.Uri]$BaseUri
    )

    $set = New-Object 'System.Collections.Generic.HashSet[string]'

    if ([string]::IsNullOrWhiteSpace($Text)) { return $set }

    $patterns = @(
        'src\s*=\s*["'']([^"''>\s]+)',
        'href\s*=\s*["'']([^"''>\s]+)',
        'srcset\s*=\s*["'']([^"'']+)',
        'url\(\s*["'']?([^\)"'']+)["'']?\s*\)'
    )

    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($Text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        foreach ($match in $matches) {
            $raw = $match.Groups[1].Value.Trim()
            if ([string]::IsNullOrWhiteSpace($raw)) { continue }

            if ($pattern -like 'srcset*') {
                $parts = $raw -split ','
                foreach ($part in $parts) {
                    $u = ($part.Trim() -split '\s+')[0]
                    $abs = Get-AbsoluteUrl -MaybeUrl $u -BaseUri $BaseUri
                    if ($abs) { [void]$set.Add($abs) }
                }
            }
            else {
                $abs = Get-AbsoluteUrl -MaybeUrl $raw -BaseUri $BaseUri
                if ($abs) { [void]$set.Add($abs) }
            }
        }
    }

    return $set
}

function Get-AssetType {
    param([System.Uri]$Uri)

    $ext = [System.IO.Path]::GetExtension($Uri.AbsolutePath).ToLowerInvariant()
    switch ($ext) {
        '.css' { return 'css' }
        '.js' { return 'js' }
        '.mjs' { return 'js' }
        '.png' { return 'image' }
        '.jpg' { return 'image' }
        '.jpeg' { return 'image' }
        '.gif' { return 'image' }
        '.webp' { return 'image' }
        '.svg' { return 'image' }
        '.avif' { return 'image' }
        '.ico' { return 'image' }
        '.woff' { return 'font' }
        '.woff2' { return 'font' }
        '.ttf' { return 'font' }
        '.otf' { return 'font' }
        '.eot' { return 'font' }
        '.map' { return 'other' }
        default {
            if ($Uri.AbsolutePath -match '/wp-content/' -or $Uri.AbsolutePath -match '/wp-includes/') {
                return 'other'
            }
            return 'other'
        }
    }
}

function Replace-AbsoluteDomainToRoot {
    param(
        [string]$Text,
        [string]$Domain
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return $Text }

    $escaped = [regex]::Escape("https://$Domain/")
    $out = [regex]::Replace($Text, $escaped, '/', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $out = [regex]::Replace($out, '<base\s+href=["'']https?://[^"'']+["'']\s*/?>', '<base href="/">', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    return $out
}

$root = Normalize-RootUrl -Url $RootUrl
$rootUri = [System.Uri]$root
$domain = $rootUri.Host
$baseDir = (Resolve-Path $OutputDir).Path

Write-Log "Start migratie voor $root"

$analysis = [ordered]@{}
$failedDownloads = New-Object System.Collections.Generic.List[string]
$downloadedAssets = New-Object 'System.Collections.Generic.HashSet[string]'
$allPageFiles = New-Object System.Collections.Generic.List[string]

# Stap 1 - Analyse homepage + sitemap detectie
$homeHtml = Get-UrlContent -Url $root
$analysis.HomepageSource = $root
$analysis.HomepageLength = $homeHtml.Length
$analysis.CmsDetected = if ($homeHtml -match 'wp-content|wp-includes|wordpress') { 'WordPress' } elseif ($homeHtml -match 'elementor') { 'Elementor (mogelijk op WordPress)' } else { 'Onbekend' }
$analysis.RootRelativeHints = @()
foreach ($hint in @('/.cm4all/', '/assets/', '/wp-content/', '/wp-includes/')) {
    if ($homeHtml -match [regex]::Escape($hint)) {
        $analysis.RootRelativeHints += $hint
    }
}

$cssMatches = [regex]::Matches($homeHtml, '<link[^>]+href\s*=\s*["'']([^"'']+)["''][^>]*>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$jsMatches = [regex]::Matches($homeHtml, '<script[^>]+src\s*=\s*["'']([^"'']+)["''][^>]*>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

$analysis.CssRefs = @($cssMatches | ForEach-Object { $_.Groups[1].Value })
$analysis.JsRefs = @($jsMatches | ForEach-Object { $_.Groups[1].Value })

$sitemap = Resolve-SitemapUrl -Root $root
$analysis.SitemapUrl = $sitemap.Url

# Sitemap URLs verzamelen
$allUrls = New-Object 'System.Collections.Generic.HashSet[string]'

function Add-UrlsFromSitemapXml {
    param([string]$XmlText)

    try {
        [xml]$xml = $XmlText
    }
    catch {
        return @()
    }

    $urls = @()

    if ($xml.urlset -and $xml.urlset.url) {
        foreach ($u in $xml.urlset.url) {
            if ($u.loc) {
                $urls += $u.loc
            }
        }
    }

    if ($xml.sitemapindex -and $xml.sitemapindex.sitemap) {
        foreach ($s in $xml.sitemapindex.sitemap) {
            if ($s.loc) {
                $urls += $s.loc
            }
        }
    }

    return $urls
}

$seedEntries = Add-UrlsFromSitemapXml -XmlText $sitemap.Content
$queue = New-Object System.Collections.Generic.Queue[string]
foreach ($entry in $seedEntries) {
    if ($allUrls.Add($entry)) {
        $queue.Enqueue($entry)
    }
}

while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()
    try {
        $uri = [System.Uri]$current
    }
    catch {
        continue
    }

    if ($uri.Host -ne $domain) { continue }

    if ($uri.AbsolutePath -match '\.xml$') {
        $res = Try-Get-UrlContent -Url $current
        if ($res.Success -and $res.Content) {
            $entries = Add-UrlsFromSitemapXml -XmlText $res.Content
            foreach ($e in $entries) {
                if ($allUrls.Add($e)) {
                    $queue.Enqueue($e)
                }
            }
        }
        continue
    }
}

# Alleen html pagina URL's op eigen domein
$pageUrls = @()
foreach ($u in $allUrls) {
    try {
        $uri = [System.Uri]$u
    }
    catch {
        continue
    }

    if ($uri.Host -ne $domain) { continue }
    if ($uri.AbsolutePath -match '\.xml$') { continue }

    $pageUrls += $uri.AbsoluteUri
}

if (-not ($pageUrls -contains $root)) {
    $pageUrls += $root
}

$pageUrls = $pageUrls | Sort-Object -Unique

Write-Log ("Te spiegelen pagina's: " + $pageUrls.Count)

# Stap 2 - Pagina's spiegelen en base-tag injecteren
foreach ($pageUrl in $pageUrls) {
    $res = Try-Get-UrlContent -Url $pageUrl
    if (-not $res.Success) {
        $failedDownloads.Add("HTML: $pageUrl :: $($res.Error)")
        continue
    }

    $uri = [System.Uri]$pageUrl
    $outFile = Get-LocalPathForPage -Url $uri -BaseDir $baseDir
    $outDir = Split-Path -Parent $outFile
    Ensure-Directory -Path $outDir

    $html = Inject-BaseTag -Html $res.Content -Domain $domain
    [System.IO.File]::WriteAllText($outFile, $html, [System.Text.Encoding]::UTF8)
    $allPageFiles.Add($outFile)
}

# Stap 3 - Assets verzamelen uit HTML
$assetQueue = New-Object System.Collections.Generic.Queue[string]
$seenAssetCandidates = New-Object 'System.Collections.Generic.HashSet[string]'

foreach ($pageFile in $allPageFiles) {
    $html = Get-Content -LiteralPath $pageFile -Raw -Encoding UTF8
    $refs = Extract-UrlsFromText -Text $html -BaseUri $rootUri
    foreach ($r in $refs) {
        if ($seenAssetCandidates.Add($r)) {
            $assetQueue.Enqueue($r)
        }
    }
}

$assetStats = [ordered]@{ image = 0; js = 0; css = 0; font = 0; other = 0 }
$downloadedCssFiles = New-Object System.Collections.Generic.List[string]
$downloadedJsFiles = New-Object System.Collections.Generic.List[string]

while ($assetQueue.Count -gt 0) {
    $assetUrl = $assetQueue.Dequeue()

    try {
        $assetUri = [System.Uri]$assetUrl
    }
    catch {
        continue
    }

    if ($assetUri.Host -ne $domain) { continue }

    if ($downloadedAssets.Contains($assetUri.AbsoluteUri)) { continue }

    $target = Get-LocalPathForAsset -Url $assetUri -BaseDir $baseDir
    if (-not $target) { continue }

    $targetDir = Split-Path -Parent $target
    Ensure-Directory -Path $targetDir

    try {
        Invoke-WebRequest -Uri $assetUri.AbsoluteUri -OutFile $target -UseBasicParsing -TimeoutSec 60
        [void]$downloadedAssets.Add($assetUri.AbsoluteUri)

        $assetType = Get-AssetType -Uri $assetUri
        if ($assetStats.Contains($assetType)) {
            $assetStats[$assetType]++
        }
        else {
            $assetStats.other++
        }

        if ($assetType -eq 'css') {
            $downloadedCssFiles.Add($target)
        }
        elseif ($assetType -eq 'js') {
            $downloadedJsFiles.Add($target)
        }
    }
    catch {
        $failedDownloads.Add("ASSET: $($assetUri.AbsoluteUri) :: $($_.Exception.Message)")
    }
}

# Stap 3b - url() refs in CSS (eigen domein)
foreach ($cssFile in ($downloadedCssFiles | Sort-Object -Unique)) {
    $cssText = Get-Content -LiteralPath $cssFile -Raw -Encoding UTF8
    $refs = Extract-UrlsFromText -Text $cssText -BaseUri $rootUri

    foreach ($r in $refs) {
        try {
            $uri = [System.Uri]$r
        }
        catch {
            continue
        }

        if ($uri.Host -ne $domain) { continue }
        if ($downloadedAssets.Contains($uri.AbsoluteUri)) { continue }

        $target = Get-LocalPathForAsset -Url $uri -BaseDir $baseDir
        if (-not $target) { continue }

        $targetDir = Split-Path -Parent $target
        Ensure-Directory -Path $targetDir

        try {
            Invoke-WebRequest -Uri $uri.AbsoluteUri -OutFile $target -UseBasicParsing -TimeoutSec 60
            [void]$downloadedAssets.Add($uri.AbsoluteUri)
            $assetType = Get-AssetType -Uri $uri
            if ($assetStats.Contains($assetType)) { $assetStats[$assetType]++ } else { $assetStats.other++ }
        }
        catch {
            $failedDownloads.Add("CSS-REF: $($uri.AbsoluteUri) :: $($_.Exception.Message)")
        }
    }
}

# Stap 3c - optioneel JS references scannen
foreach ($jsFile in ($downloadedJsFiles | Sort-Object -Unique)) {
    $jsText = Get-Content -LiteralPath $jsFile -Raw -Encoding UTF8
    $refs = Extract-UrlsFromText -Text $jsText -BaseUri $rootUri

    foreach ($r in $refs) {
        try {
            $uri = [System.Uri]$r
        }
        catch {
            continue
        }

        if ($uri.Host -ne $domain) { continue }
        if ($downloadedAssets.Contains($uri.AbsoluteUri)) { continue }

        $target = Get-LocalPathForAsset -Url $uri -BaseDir $baseDir
        if (-not $target) { continue }

        $targetDir = Split-Path -Parent $target
        Ensure-Directory -Path $targetDir

        try {
            Invoke-WebRequest -Uri $uri.AbsoluteUri -OutFile $target -UseBasicParsing -TimeoutSec 60
            [void]$downloadedAssets.Add($uri.AbsoluteUri)
            $assetType = Get-AssetType -Uri $uri
            if ($assetStats.Contains($assetType)) { $assetStats[$assetType]++ } else { $assetStats.other++ }
        }
        catch {
            $failedDownloads.Add("JS-REF: $($uri.AbsoluteUri) :: $($_.Exception.Message)")
        }
    }
}

# Stap 4 - paden herschrijven
$rewrittenFiles = New-Object System.Collections.Generic.List[string]

foreach ($file in $allPageFiles) {
    $txt = Get-Content -LiteralPath $file -Raw -Encoding UTF8
    $new = Replace-AbsoluteDomainToRoot -Text $txt -Domain $domain
    if ($new -ne $txt) {
        [System.IO.File]::WriteAllText($file, $new, [System.Text.Encoding]::UTF8)
        $rewrittenFiles.Add($file)
    }
}

$cssFiles = Get-ChildItem -Path $baseDir -Recurse -File -Filter *.css -ErrorAction SilentlyContinue
foreach ($f in $cssFiles) {
    $txt = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $new = Replace-AbsoluteDomainToRoot -Text $txt -Domain $domain
    if ($new -ne $txt) {
        [System.IO.File]::WriteAllText($f.FullName, $new, [System.Text.Encoding]::UTF8)
        $rewrittenFiles.Add($f.FullName)
    }
}

$jsFiles = Get-ChildItem -Path $baseDir -Recurse -File -Filter *.js -ErrorAction SilentlyContinue
foreach ($f in $jsFiles) {
    $txt = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $new = Replace-AbsoluteDomainToRoot -Text $txt -Domain $domain
    if ($new -ne $txt) {
        [System.IO.File]::WriteAllText($f.FullName, $new, [System.Text.Encoding]::UTF8)
        $rewrittenFiles.Add($f.FullName)
    }
}

# Stap 5 - verificatie
$verification = New-Object System.Collections.Generic.List[object]
$htmlWithDomainRefs = New-Object System.Collections.Generic.List[string]

foreach ($file in $allPageFiles) {
    $txt = Get-Content -LiteralPath $file -Raw -Encoding UTF8

    $hasBase = $txt -match '<base\s+href=["'']/["'']\s*/?>'
    $hasScript = $txt -match '<script\b'
    $hasStyle = ($txt -match '<style\b') -or ($txt -match '<link[^>]+rel=["''][^"'']*stylesheet')
    $endsHtml = $txt.TrimEnd().ToLowerInvariant().EndsWith('</html>')
    $hasDomain = $txt -match [regex]::Escape("https://$domain/")

    if ($hasDomain) {
        $htmlWithDomainRefs.Add($file)
    }

    $verification.Add([pscustomobject]@{
        File = $file
        HasBaseRoot = $hasBase
        HasScript = $hasScript
        HasStyle = $hasStyle
        EndsWithHtmlClose = $endsHtml
        HasRemainingDomainRefs = $hasDomain
    })
}

# Externe afhankelijkheden detectie
$externalDeps = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($file in $allPageFiles) {
    $txt = Get-Content -LiteralPath $file -Raw -Encoding UTF8
    $matches = [regex]::Matches($txt, 'https?://([^/"''\s>]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($m in $matches) {
        $depHost = $m.Groups[1].Value.ToLowerInvariant()
        if ($depHost -and $depHost -ne $domain) {
            [void]$externalDeps.Add($depHost)
        }
    }
}

# Overzicht bestanden
function Convert-ToRelativeWebPath {
    param(
        [string]$Path,
        [string]$BasePath
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $relative = $Path
    if ($relative.StartsWith($BasePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $relative.Substring($BasePath.Length)
    }
    $relative = $relative -replace '^[\\/]+', ''
    return $relative -replace '\\','/'
}

$fileManifest = $allPageFiles | Sort-Object | ForEach-Object {
    Convert-ToRelativeWebPath -Path $_ -BasePath $baseDir
}

$rewrittenUnique = @($rewrittenFiles | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
$rewrittenRelative = @($rewrittenUnique | ForEach-Object { Convert-ToRelativeWebPath -Path ([string]$_) -BasePath $baseDir })
$remainingDomainRefRelative = @($htmlWithDomainRefs | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Convert-ToRelativeWebPath -Path ([string]$_) -BasePath $baseDir })

$report = [ordered]@{
    rootUrl = $root
    domain = $domain
    analysis = $analysis
    mirroredHtmlPages = $allPageFiles.Count
    mirroredFiles = $fileManifest
    totalDownloadedAssets = $downloadedAssets.Count
    assetBreakdown = $assetStats
    failedDownloads = @($failedDownloads)
    rewrittenPathsCount = $rewrittenUnique.Count
    rewrittenPaths = $rewrittenRelative
    verification = @($verification)
    htmlFilesWithRemainingDomainRefs = $remainingDomainRefRelative
    externalDependencies = @($externalDeps | Sort-Object)
}

$reportPath = Join-Path $baseDir 'migration-report.json'
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Log "Migratie voltooid. Rapport: $reportPath"
Write-Log ("HTML pagina's: " + $allPageFiles.Count)
Write-Log ("Assets gedownload: " + $downloadedAssets.Count)
Write-Log ("Mislukte downloads: " + $failedDownloads.Count)
