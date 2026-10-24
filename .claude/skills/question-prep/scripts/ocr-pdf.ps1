# स्कैन किए PDF (जिसमें पाठ की परत नहीं) से Windows के अपने OCR से पाठ.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File ocr-pdf.ps1 -Pdf "<file.pdf>" -Out "<out.txt>"
#   ... -Dpi 200 -From 3 -To 10 -Lang en-US
#
# Tesseract इस मशीन पर नहीं है. पन्ने pymupdf से PNG बनते हैं (Python में
# pymupdf पहले से है), फिर Windows.Media.Ocr पढ़ता है.
#
# ⚠️ OCR की भाषाएँ सिर्फ़ en-US और en-GB हैं — हिंदी नहीं. हिंदी स्कैन के लिए
#    tools/pdfserve.js से पन्ने आँख से पढ़िए.
param(
  [Parameter(Mandatory = $true)][string]$Pdf,
  [Parameter(Mandatory = $true)][string]$Out,
  [int]$Dpi = 150,
  [int]$From = 1,
  [int]$To = 0,
  [string]$Lang = 'en-US'
)

$ErrorActionPreference = 'Stop'
$Pdf = (Resolve-Path $Pdf).Path

# पन्नों की तस्वीरें अलग अस्थायी फ़ोल्डर में, ताकि PDF वाले फ़ोल्डर में कचरा न बने.
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("ocr-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {

$py = @'
import sys, pymupdf
pdf, out, dpi, a, b = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
doc = pymupdf.open(pdf)
b = len(doc) if b <= 0 or b > len(doc) else b
for i in range(a - 1, b):
    doc[i].get_pixmap(dpi=dpi).save(f"{out}/p{i + 1:04d}.png")
print(b - a + 1)
'@
$pyFile = Join-Path $tmp 'render.py'
Set-Content -Path $pyFile -Value $py -Encoding utf8
$n = & python -I $pyFile $Pdf $tmp $Dpi $From $To
if ($LASTEXITCODE -ne 0) { throw "pymupdf से पन्ने नहीं बने" }

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime]
$null = [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]

# WinRT के async को PowerShell 5.1 में रुककर पूरा करवाने का तरीक़ा.
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
  })[0]
function Await($op, [Type]$type) {
  $task = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
  $task.Wait(-1) | Out-Null
  $task.Result
}

$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new($Lang))
if ($null -eq $engine) { throw "OCR भाषा '$Lang' install नहीं है" }

$lines = New-Object System.Collections.Generic.List[string]
foreach ($png in Get-ChildItem $tmp -Filter *.png | Sort-Object Name) {
  $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($png.FullName)) ([Windows.Storage.StorageFile])
  $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
  $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
  $result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
  $stream.Dispose()

  $page = [int]($png.BaseName.Substring(1))
  $lines.Add("===== पन्ना $page =====")
  foreach ($l in $result.Lines) { $lines.Add($l.Text) }
}

[IO.File]::WriteAllLines($Out, $lines, (New-Object System.Text.UTF8Encoding $false))
Write-Output "$n पन्ने → $Out"

} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
