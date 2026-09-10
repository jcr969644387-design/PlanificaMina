# Genera los efectos de sonido de la interfaz como WAV PCM de 16 bits.
#
# Se sintetizan en vez de descargarse por dos razones: no dependemos de
# archivos de terceros con licencias que auditar, y el resultado es
# reproducible — cualquiera puede regenerarlos ejecutando este script.
#
# Uso: ./tools/gen_sounds.ps1 "assets/sounds"

param([string]$OutDir = "assets/sounds")

$rate = 44100

# Escribe un WAV mono de 16 bits a partir de un array de muestras en [-1, 1].
function Write-Wav($path, $samples) {
    $n = $samples.Count
    $dataBytes = $n * 2
    $fs = New-Object System.IO.FileStream($path, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter($fs)

    $bw.Write([char[]]"RIFF")
    $bw.Write([int](36 + $dataBytes))
    $bw.Write([char[]]"WAVE")
    $bw.Write([char[]]"fmt ")
    $bw.Write([int]16)          # tamaño del bloque fmt
    $bw.Write([int16]1)         # PCM sin comprimir
    $bw.Write([int16]1)         # mono
    $bw.Write([int]$rate)
    $bw.Write([int]($rate * 2)) # bytes por segundo
    $bw.Write([int16]2)         # alineación de bloque
    $bw.Write([int16]16)        # bits por muestra
    $bw.Write([char[]]"data")
    $bw.Write([int]$dataBytes)

    foreach ($s in $samples) {
        $v = [Math]::Max(-1.0, [Math]::Min(1.0, $s))
        $bw.Write([int16]([Math]::Round($v * 32000)))
    }
    $bw.Close()
    $fs.Close()
    Write-Output ("{0}  ({1} ms)" -f $path, [int](1000.0 * $n / $rate))
}

# Un tono con envolvente exponencial. El ataque de 3 ms y la caída suave
# evitan el chasquido que produce cortar una onda en seco.
function Tone($freq, $ms, $amp, $decay, $freqEnd = 0) {
    $n = [int]($rate * $ms / 1000.0)
    $out = New-Object 'double[]' $n
    $attack = [int]($rate * 0.003)
    for ($i = 0; $i -lt $n; $i++) {
        $t = $i / [double]$rate
        $prog = $i / [double]$n
        $f = if ($freqEnd -gt 0) { $freq + ($freqEnd - $freq) * $prog } else { $freq }
        $env = [Math]::Exp(-$decay * $t)
        if ($i -lt $attack) { $env *= ($i / [double]$attack) }
        $out[$i] = $amp * $env * [Math]::Sin(2.0 * [Math]::PI * $f * $t)
    }
    return $out
}

function Mix($a, $b, $offsetMs) {
    $off = [int]($rate * $offsetMs / 1000.0)
    $len = [Math]::Max($a.Count, $off + $b.Count)
    $out = New-Object 'double[]' $len
    for ($i = 0; $i -lt $a.Count; $i++) { $out[$i] += $a[$i] }
    for ($i = 0; $i -lt $b.Count; $i++) { $out[$off + $i] += $b[$i] }
    return $out
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }

# select: lo más leve. Elegir una opción de una lista.
Write-Wav "$OutDir/select.wav" (Tone 1800 45 0.22 90)

# tap: pulsar un botón o una tarjeta. Un punto más cuerpo que select.
Write-Wav "$OutDir/tap.wav" (Tone 1150 60 0.30 60)

# section: cambio de pestaña. Dos notas ascendentes, sugiere "he ido a otro sitio".
Write-Wav "$OutDir/section.wav" (Mix (Tone 780 70 0.26 55) (Tone 1170 90 0.26 45) 55)

# success: acción completada. Tercera mayor ascendente, corta.
Write-Wav "$OutDir/success.wav" (Mix (Tone 880 90 0.28 40) (Tone 1320 150 0.28 30) 75)

# warning: algo falló. Desciende, que es la convención para el error.
Write-Wav "$OutDir/warning.wav" (Tone 520 190 0.26 22 380)
