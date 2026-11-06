param (
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Ejemplo: 1.0.1 o v1.0.1")]
    [string]$Version,

    [Parameter(Mandatory=$false, Position=1)]
    [string]$Notas = "Mejoras de rendimiento y corrección de errores."
)

# Asegurar formato del tag con 'v' (ej: v1.0.1) y de pubspec sin 'v' (ej: 1.0.1)
$tag = if ($Version.StartsWith("v") -or $Version.StartsWith("V")) { $Version } else { "v$Version" }
$versionPura = $tag.Substring(1).Split('+')[0]

Write-Host ""
Write-Host "🚀 Iniciando publicación automática para $tag..." -ForegroundColor Cyan

# 1. Actualizar la versión en pubspec.yaml
$pubspecPath = "pubspec.yaml"
if (Test-Path $pubspecPath) {
    $contenido = Get-Content $pubspecPath -Raw
    $contenidoNuevo = $contenido -replace 'version:\s*[0-9\.\+\-]+', "version: $versionPura+1"
    Set-Content -Path $pubspecPath -Value $contenidoNuevo -NoNewline
    Write-Host "✔ pubspec.yaml actualizado a versión: $versionPura+1" -ForegroundColor Green
}

# 2. Preparar cambios en git
Write-Host "📦 Guardando cambios en Git..." -ForegroundColor Cyan
git add .

# 3. Crear commit
git commit -m "chore(release): version $tag - $Notas"
Write-Host "✔ Commit creado exitosamente" -ForegroundColor Green

# 4. Crear etiqueta de release
git tag -a $tag -m "$Notas"
Write-Host "✔ Etiqueta $tag creada" -ForegroundColor Green

# 5. Enviar a GitHub
Write-Host "☁ Subiendo cambios y etiqueta a GitHub..." -ForegroundColor Cyan
git push origin master
git push origin $tag

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "🎉 ¡ÉXITO! Se ha lanzado la publicación de $tag." -ForegroundColor Green
Write-Host "GitHub Actions está compilando el APK en la nube en este momento." -ForegroundColor Yellow
Write-Host "En aproximadamente 2 minutos estará disponible en GitHub Releases" -ForegroundColor Yellow
Write-Host "y tu teléfono mostrará la ventana para actualizar." -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Green

