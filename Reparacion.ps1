#Requires -Version 5.1
<#
.SYNOPSIS
    Herramienta profesional de gestión y mantenimiento del sistema Windows.
.DESCRIPTION
    Menú interactivo con diagnóstico, reparación, monitoreo, respaldos,
    gestión de discos, red, servicios y generación de reportes HTML.
.NOTES
    Requiere ejecución como Administrador.
    Autor: Sistema de Mantenimiento Pro
    Versión: 2.0
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# ─────────────────────────────────────────────────────────────
#  CONFIGURACIÓN GLOBAL
# ─────────────────────────────────────────────────────────────
$Script:Config = @{
    LogDir       = "$env:SystemDrive\MantenimientoPro\Logs"
    ReportDir    = "$env:SystemDrive\MantenimientoPro\Reportes"
    BackupDir    = "$env:SystemDrive\MantenimientoPro\Respaldos"
    Version      = "2.0"
    LogFile      = ""          # Se asigna al iniciar
    ErrorCount   = 0
}

# ─────────────────────────────────────────────────────────────
#  SISTEMA DE LOGGING
# ─────────────────────────────────────────────────────────────
function Initialize-Environment {
    foreach ($dir in @($Script:Config.LogDir, $Script:Config.ReportDir, $Script:Config.BackupDir)) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $Script:Config.LogFile = Join-Path $Script:Config.LogDir "sesion_$timestamp.log"
    Write-Log "===== SESIÓN INICIADA — v$($Script:Config.Version) =====" -Level INFO
    Write-Log "Usuario: $env:USERNAME | Equipo: $env:COMPUTERNAME" -Level INFO
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR","SUCCESS")][string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp][$Level] $Message"
    Add-Content -Path $Script:Config.LogFile -Value $entry -Encoding UTF8

    $colors = @{ INFO="Cyan"; WARN="Yellow"; ERROR="Red"; SUCCESS="Green" }
    Write-Host $entry -ForegroundColor $colors[$Level]
}

# ─────────────────────────────────────────────────────────────
#  HELPERS REUTILIZABLES
# ─────────────────────────────────────────────────────────────
function Confirm-Action {
    param([string]$Mensaje, [string]$Titulo = "Confirmar acción")
    $result = [System.Windows.Forms.MessageBox]::Show(
        $Mensaje, $Titulo,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Show-Progress {
    param([string]$Activity, [string]$Status, [int]$PercentComplete)
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    return "{0:N2} KB" -f ($Bytes / 1KB)
}

function Invoke-ConElevacion {
    param([scriptblock]$Accion, [string]$Nombre = "Operación")
    Write-Log "Iniciando: $Nombre" -Level INFO
    try {
        & $Accion
        Write-Log "Completado: $Nombre" -Level SUCCESS
    } catch {
        $Script:Config.ErrorCount++
        Write-Log "Error en '$Nombre': $_" -Level ERROR
        [System.Windows.Forms.MessageBox]::Show(
            "Error en '$Nombre':`n$_", "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

function Pause-Screen {
    Write-Host "`nPresione ENTER para volver al menú..." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

# ─────────────────────────────────────────────────────────────
#  MENÚ PRINCIPAL
# ─────────────────────────────────────────────────────────────
function Show-Menu {
    do {
        Clear-Host
        Write-Host @"
╔══════════════════════════════════════════════════════╗
║       HERRAMIENTA DE MANTENIMIENTO PRO v2.0          ║
║       Equipo: $env:COMPUTERNAME  |  Usuario: $env:USERNAME
║       Sesión: $(Get-Date -Format 'dd/MM/yyyy HH:mm')              ║
╚══════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

        $categorias = [ordered]@{
            "── 🔧 DIAGNÓSTICO Y REPARACIÓN ──────────────────"  = $null
            "   1. Diagnóstico completo del sistema"              = "Realizar-Diagnostico"
            "   2. Escaneo y reparación de disco (CHKDSK)"       = "Escaneo-Reparacion-Disco"
            "   3. Reparar Windows Update"                        = "Reparar-WindowsUpdate"
            "── 💾 DISCOS Y PARTICIONES ──────────────────────"  = $null
            "   4. Crear partición"                               = "Crear-Particion"
            "   5. Borrar partición"                              = "Borrar-Particion"
            "   6. Formatear partición"                           = "Formatear-Particion"
            "   7. Desfragmentar disco"                           = "Desfragmentar-Disco"
            "   8. Analizar espacio en disco"                     = "Analizar-EspacioDisco"
            "── 🌐 RED Y CONECTIVIDAD ────────────────────────"  = $null
            "   9. Diagnóstico de red"                            = "Diagnostico-Red"
            "  10. Reparar red y DNS"                             = "Reparar-Red"
            "  11. Ver conexiones activas"                        = "Ver-Conexiones"
            "── ⚙️  SISTEMA Y SOFTWARE ───────────────────────"  = $null
            "  12. Actualizar programas (winget)"                 = "Actualizar-Programas"
            "  13. Instalar programa"                             = "Instalar-Programa"
            "  14. Desinstalar programa"                          = "Desinstalar-Programa"
            "  15. Gestionar servicios de Windows"                = "Gestionar-Servicios"
            "  16. Opciones de inicio (msconfig)"                 = "msconfig"
            "  17. Optimizar sistema"                             = "Optimizar-Sistema"
            "  18. Limpiar archivos basura"                       = "Limpiar-Basura"
            "── 📊 INFORMACIÓN Y REPORTES ────────────────────"  = $null
            "  19. Información completa del hardware"             = "Mostrar-Info"
            "  20. Información de drivers"                        = "Mostrar-Drivers"
            "  21. Monitoreo en tiempo real (CPU/RAM/Disco)"      = "Monitor-Recursos"
            "  22. Generar reporte HTML completo"                 = "Generar-ReporteHTML"
            "── 🔒 SEGURIDAD ─────────────────────────────────"  = $null
            "  23. Escanear con Windows Defender"                 = "Escanear-Defender"
            "  24. Ver y gestionar tareas programadas"            = "Gestionar-TareasProgramadas"
            "  25. Auditoría de usuarios y sesiones"              = "Auditoria-Usuarios"
            "── 💿 RESPALDO Y RESTAURACIÓN ───────────────────"  = $null
            "  26. Hacer respaldo del sistema"                    = "Hacer-Respaldo"
            "  27. Restaurar el sistema"                          = "rstrui"
            "  28. Ver log de esta sesión"                        = "Ver-Log"
            "─────────────────────────────────────────────────"  = $null
            "  29. Salir"                                         = "SALIR"
        }

        $opciones = $categorias.Keys | Where-Object { $categorias[$_] -ne $null -and $_ -notlike "──*" -and $_ -notlike "──*" }

        $choice = $opciones | Out-GridView -Title "MANTENIMIENTO PRO v2.0 — Seleccione una opción" -PassThru

        if ($null -eq $choice) { break }

        $funcion = $categorias[$choice]

        if ($funcion -eq "SALIR") {
            Write-Log "Sesión finalizada. Errores registrados: $($Script:Config.ErrorCount)" -Level INFO
            Clear-Host
            Write-Host "¡Hasta luego! Log guardado en: $($Script:Config.LogFile)" -ForegroundColor Green
            break
        }

        Clear-Host

        switch ($funcion) {
            "msconfig"  { Start-Process msconfig }
            "rstrui"    { Start-Process rstrui }
            default     { & $funcion }
        }

    } while ($true)
}

# ─────────────────────────────────────────────────────────────
#  1. DIAGNÓSTICO Y REPARACIÓN
# ─────────────────────────────────────────────────────────────
function Realizar-Diagnostico {
    Invoke-ConElevacion -Nombre "Diagnóstico del sistema" -Accion {
        Write-Log "Iniciando SFC..." -Level INFO
        Show-Progress "Diagnóstico" "Ejecutando SFC /scannow..." 10
        sfc /scannow

        Show-Progress "Diagnóstico" "DISM CheckHealth..." 40
        DISM /Online /Cleanup-Image /CheckHealth

        Show-Progress "Diagnóstico" "DISM ScanHealth..." 60
        DISM /Online /Cleanup-Image /ScanHealth

        Show-Progress "Diagnóstico" "DISM RestoreHealth..." 80
        DISM /Online /Cleanup-Image /RestoreHealth

        Write-Progress -Completed -Activity "Diagnóstico"
        Write-Log "Diagnóstico completado exitosamente." -Level SUCCESS
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  2. ESCANEO DE DISCO (CHKDSK)
# ─────────────────────────────────────────────────────────────
function Escaneo-Reparacion-Disco {
    $volumenes = Get-Volume | Where-Object { $_.DriveLetter } |
        Select-Object @{N="Unidad";E={"$($_.DriveLetter):"}},
                      @{N="Nombre";E={$_.FileSystemLabel}},
                      @{N="Sistema";E={$_.FileSystem}},
                      @{N="Libre";E={ Format-Bytes $_.SizeRemaining }},
                      @{N="Total";E={ Format-Bytes $_.Size }}

    $seleccion = $volumenes | Out-GridView -Title "Seleccione el disco a escanear" -PassThru
    if ($null -eq $seleccion) { return }

    $letra = $seleccion.Unidad.TrimEnd(':')

    if (Confirm-Action "¿Ejecutar CHKDSK en la unidad $($seleccion.Unidad)?`nPuede requerir reinicio si el disco está en uso.") {
        Invoke-ConElevacion -Nombre "CHKDSK $($seleccion.Unidad)" -Accion {
            Write-Log "CHKDSK iniciado en $($seleccion.Unidad)" -Level INFO
            chkdsk "$($seleccion.Unidad)" /f /r /x
        }
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  3. REPARAR WINDOWS UPDATE
# ─────────────────────────────────────────────────────────────
function Reparar-WindowsUpdate {
    if (-not (Confirm-Action "¿Desea reparar Windows Update?`nSe reiniciarán los servicios relacionados y se limpiarán cachés.")) { return }

    Invoke-ConElevacion -Nombre "Reparar Windows Update" -Accion {
        $servicios = @("wuauserv", "bits", "cryptsvc", "msiserver")

        Write-Log "Deteniendo servicios de Windows Update..." -Level INFO
        Stop-Service -Name $servicios -Force -ErrorAction SilentlyContinue

        Write-Log "Renombrando carpetas de caché..." -Level INFO
        $carpetas = @(
            "$env:SystemRoot\SoftwareDistribution",
            "$env:SystemRoot\System32\catroot2"
        )
        foreach ($c in $carpetas) {
            if (Test-Path $c) {
                $backup = "${c}_bak_$(Get-Date -Format 'yyyyMMddHHmm')"
                Rename-Item -Path $c -NewName $backup -ErrorAction SilentlyContinue
                Write-Log "Renombrado: $c → $backup" -Level INFO
            }
        }

        Write-Log "Registrando DLLs de Windows Update..." -Level INFO
        $dlls = @("atl.dll","urlmon.dll","mshtml.dll","shdocvw.dll","browseui.dll",
                  "jscript.dll","vbscript.dll","scrrun.dll","msxml.dll","msxml3.dll",
                  "msxml6.dll","actxprxy.dll","softpub.dll","wintrust.dll","dssenh.dll",
                  "rsaenh.dll","cryptdlg.dll","oleaut32.dll","ole32.dll","shell32.dll",
                  "wuapi.dll","wuaueng.dll","wuaueng1.dll","wucltui.dll","wups.dll",
                  "wups2.dll","wuweb.dll","qmgr.dll","qmgrprxy.dll","wucltux.dll",
                  "muweb.dll","wuwebv.dll")
        foreach ($dll in $dlls) {
            regsvr32 /s $dll
        }

        Write-Log "Reiniciando servicios..." -Level INFO
        Start-Service -Name $servicios -ErrorAction SilentlyContinue

        Write-Log "Windows Update reparado correctamente." -Level SUCCESS
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  4. CREAR PARTICIÓN
# ─────────────────────────────────────────────────────────────
function Crear-Particion {
    Write-Log "Iniciando creación de partición" -Level INFO

    $discos = Get-Disk | Select-Object Number,
        @{N="Nombre";E={$_.FriendlyName}},
        @{N="Tamaño";E={ Format-Bytes $_.Size }},
        PartitionStyle,
        @{N="Estado";E={$_.OperationalStatus}}

    $disco = $discos | Out-GridView -Title "Seleccione el disco" -PassThru
    if ($null -eq $disco) { return }

    $tipo = @("primary","extended","logical") | Out-GridView -Title "Tipo de partición" -PassThru
    if ($null -eq $tipo) { return }

    $fs = @("NTFS","FAT32","exFAT") | Out-GridView -Title "Sistema de archivos" -PassThru
    if ($null -eq $fs) { return }

    $tamanio = Read-Host "Tamaño en MB (deje vacío para usar todo el espacio libre)"
    $nom = Read-Host "Etiqueta de la partición"
    $let = Read-Host "Letra de unidad a asignar (ej: D)"

    $sizeCmd = if ($tamanio -match '^\d+$') { "size=$tamanio" } else { "" }

    if (-not (Confirm-Action "¿Crear partición $tipo ($fs) en Disco $($disco.Number)?")) { return }

    $script = @"
select disk $($disco.Number)
create partition $tipo $sizeCmd
format fs=$fs label="$nom" quick
assign letter=$let
exit
"@
    Invoke-ConElevacion -Nombre "Crear partición" -Accion {
        $script | diskpart
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  5. BORRAR PARTICIÓN
# ─────────────────────────────────────────────────────────────
function Borrar-Particion {
    $particiones = Get-Partition | Where-Object { $_.DriveLetter } |
        Select-Object DiskNumber, PartitionNumber, DriveLetter,
            @{N="Tamaño";E={ Format-Bytes $_.Size }}, Type

    $sel = $particiones | Out-GridView -Title "Seleccione la partición a borrar" -PassThru
    if ($null -eq $sel) { return }

    if (-not (Confirm-Action "⚠️ ¿BORRAR la partición $($sel.DriveLetter): del disco $($sel.DiskNumber)?`n¡Esta acción es IRREVERSIBLE y borrará todos los datos!")) { return }

    Invoke-ConElevacion -Nombre "Borrar partición $($sel.DriveLetter):" -Accion {
        $s = @"
select disk $($sel.DiskNumber)
select partition $($sel.PartitionNumber)
delete partition override
exit
"@
        $s | diskpart
        Write-Log "Partición $($sel.DriveLetter): borrada." -Level SUCCESS
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  6. FORMATEAR PARTICIÓN
# ─────────────────────────────────────────────────────────────
function Formatear-Particion {
    $particiones = Get-Partition | Where-Object { $_.DriveLetter } |
        Select-Object DiskNumber, PartitionNumber, DriveLetter,
            @{N="Tamaño";E={ Format-Bytes $_.Size }}

    $sel = $particiones | Out-GridView -Title "Seleccione la partición a formatear" -PassThru
    if ($null -eq $sel) { return }

    $fs = @("NTFS","FAT32","exFAT") | Out-GridView -Title "Sistema de archivos" -PassThru
    if ($null -eq $fs) { return }

    $label = Read-Host "Etiqueta para la partición (opcional)"

    if (-not (Confirm-Action "⚠️ ¿FORMATEAR $($sel.DriveLetter): con $fs?`n¡Se borrarán TODOS los datos de esta unidad!")) { return }

    Invoke-ConElevacion -Nombre "Formatear $($sel.DriveLetter):" -Accion {
        $s = @"
select disk $($sel.DiskNumber)
select partition $($sel.PartitionNumber)
format fs=$fs label="$label" quick
exit
"@
        $s | diskpart
        Write-Log "Partición $($sel.DriveLetter): formateada con $fs." -Level SUCCESS
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  7. DESFRAGMENTAR DISCO
# ─────────────────────────────────────────────────────────────
function Desfragmentar-Disco {
    $volumenes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' } |
        Select-Object @{N="Unidad";E={"$($_.DriveLetter):"}},
                      @{N="Etiqueta";E={$_.FileSystemLabel}},
                      @{N="Sistema";E={$_.FileSystem}},
                      @{N="Libre";E={ Format-Bytes $_.SizeRemaining }},
                      @{N="Total";E={ Format-Bytes $_.Size }}

    $sel = $volumenes | Out-GridView -Title "Seleccione el disco a desfragmentar" -PassThru
    if ($null -eq $sel) { return }

    $modo = @("Análisis solamente (/A)","Desfragmentación optimizada (/O)","Desfragmentación completa (/U /V)") |
        Out-GridView -Title "Modo de desfragmentación" -PassThru
    if ($null -eq $modo) { return }

    $flag = switch ($modo) {
        "Análisis solamente (/A)"              { "/A" }
        "Desfragmentación optimizada (/O)"     { "/O" }
        "Desfragmentación completa (/U /V)"    { "/U /V" }
    }

    Invoke-ConElevacion -Nombre "Desfragmentar $($sel.Unidad)" -Accion {
        Write-Log "Ejecutando defrag $($sel.Unidad) $flag" -Level INFO
        Invoke-Expression "defrag $($sel.Unidad) $flag"
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  8. ANALIZAR ESPACIO EN DISCO
# ─────────────────────────────────────────────────────────────
function Analizar-EspacioDisco {
    Write-Log "Analizando espacio en disco" -Level INFO

    Write-Host "`n=== ESPACIO EN TODOS LOS VOLÚMENES ===" -ForegroundColor Cyan
    Get-Volume | Where-Object { $_.DriveLetter } | ForEach-Object {
        $pct = if ($_.Size -gt 0) { [math]::Round(($_.SizeRemaining / $_.Size) * 100, 1) } else { 0 }
        $color = if ($pct -lt 10) { "Red" } elseif ($pct -lt 20) { "Yellow" } else { "Green" }
        $bar = "█" * [math]::Floor($pct / 5) + "░" * (20 - [math]::Floor($pct / 5))
        Write-Host ("  {0}:  [{1}] {2,5}% libre   ({3} de {4})" -f `
            $_.DriveLetter, $bar, $pct, (Format-Bytes $_.SizeRemaining), (Format-Bytes $_.Size)) `
            -ForegroundColor $color
    }

    Write-Host "`n=== TOP 20 ARCHIVOS MÁS GRANDES EN C:\ ===" -ForegroundColor Cyan
    Write-Host "Escaneando... (puede tardar unos segundos)" -ForegroundColor DarkGray

    $topArchivos = Get-ChildItem -Path "C:\" -Recurse -File -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending |
        Select-Object -First 20 |
        Select-Object @{N="Tamaño";E={ Format-Bytes $_.Length }},
                      @{N="Archivo";E={$_.FullName}},
                      @{N="Modificado";E={ $_.LastWriteTime.ToString("dd/MM/yyyy") }}

    $topArchivos | Format-Table -AutoSize

    Write-Host "`n=== TOP 10 CARPETAS MÁS PESADAS EN C:\ ===" -ForegroundColor Cyan
    $carpetas = @("C:\Windows\Temp","C:\Users","C:\Program Files","C:\Program Files (x86)",
                  "$env:LOCALAPPDATA\Temp","$env:LOCALAPPDATA","C:\Windows\SoftwareDistribution")

    foreach ($c in $carpetas) {
        if (Test-Path $c) {
            $size = (Get-ChildItem $c -Recurse -File -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum).Sum
            Write-Host ("  {0,-50} {1,10}" -f $c, (Format-Bytes $size)) -ForegroundColor White
        }
    }

    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  9. DIAGNÓSTICO DE RED
# ─────────────────────────────────────────────────────────────
function Diagnostico-Red {
    Invoke-ConElevacion -Nombre "Diagnóstico de red" -Accion {
        Write-Host "`n=== ADAPTADORES DE RED ===" -ForegroundColor Cyan
        Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MacAddress | Format-Table -AutoSize

        Write-Host "`n=== DIRECCIONES IP ===" -ForegroundColor Cyan
        Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.IPAddress -ne '127.0.0.1' } |
            Select-Object InterfaceAlias, IPAddress, PrefixLength | Format-Table -AutoSize

        Write-Host "`n=== GATEWAY Y DNS ===" -ForegroundColor Cyan
        Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } |
            Select-Object InterfaceAlias,
                @{N="Gateway";E={$_.IPv4DefaultGateway.NextHop}},
                @{N="DNS";E={$_.DNSServer.ServerAddresses -join ", "}} |
            Format-Table -AutoSize

        Write-Host "`n=== PING A SERVIDORES CLAVE ===" -ForegroundColor Cyan
        $targets = @(
            @{Host="8.8.8.8";      Desc="Google DNS"},
            @{Host="1.1.1.1";      Desc="Cloudflare DNS"},
            @{Host="google.com";   Desc="Google"},
            @{Host="microsoft.com";Desc="Microsoft"}
        )
        foreach ($t in $targets) {
            $ping = Test-Connection -ComputerName $t.Host -Count 3 -ErrorAction SilentlyContinue
            if ($ping) {
                $avg = [math]::Round(($ping | Measure-Object -Property Latency -Average).Average, 1)
                Write-Host ("  ✔ {0,-20} {1,-15} Latencia promedio: {2} ms" -f $t.Desc, $t.Host, $avg) -ForegroundColor Green
            } else {
                Write-Host ("  ✘ {0,-20} {1,-15} SIN RESPUESTA" -f $t.Desc, $t.Host) -ForegroundColor Red
            }
        }

        Write-Host "`n=== TRACERT A GOOGLE ===" -ForegroundColor Cyan
        tracert -d -h 10 8.8.8.8
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  10. REPARAR RED Y DNS
# ─────────────────────────────────────────────────────────────
function Reparar-Red {
    if (-not (Confirm-Action "¿Reparar la configuración de red?`nSe reiniciará la pila TCP/IP, Winsock y la caché DNS.")) { return }

    Invoke-ConElevacion -Nombre "Reparar red" -Accion {
        Write-Log "Limpiando caché DNS..." -Level INFO
        ipconfig /flushdns

        Write-Log "Renovando IP..." -Level INFO
        ipconfig /release
        ipconfig /renew

        Write-Log "Reiniciando pila TCP/IP..." -Level INFO
        netsh int ip reset

        Write-Log "Reiniciando Winsock..." -Level INFO
        netsh winsock reset

        Write-Log "Reiniciando Firewall..." -Level INFO
        netsh advfirewall reset

        Write-Log "Red reparada. Se recomienda reiniciar el equipo." -Level SUCCESS
        Write-Host "`n⚠ Se recomienda REINICIAR el equipo para aplicar todos los cambios." -ForegroundColor Yellow
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  11. VER CONEXIONES ACTIVAS
# ─────────────────────────────────────────────────────────────
function Ver-Conexiones {
    Write-Log "Listando conexiones activas" -Level INFO

    Write-Host "`n=== CONEXIONES DE RED ACTIVAS ===" -ForegroundColor Cyan
    $conexiones = Get-NetTCPConnection | Where-Object { $_.State -eq 'Established' } |
        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State,
            @{N="Proceso";E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name}} |
        Sort-Object RemoteAddress

    $conexiones | Format-Table -AutoSize

    Write-Host "`n=== PUERTOS EN ESCUCHA ===" -ForegroundColor Cyan
    Get-NetTCPConnection | Where-Object { $_.State -eq 'Listen' } |
        Select-Object LocalAddress, LocalPort,
            @{N="Proceso";E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name}} |
        Sort-Object LocalPort |
        Format-Table -AutoSize

    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  12. ACTUALIZAR PROGRAMAS
# ─────────────────────────────────────────────────────────────
function Actualizar-Programas {
    Write-Log "Verificando actualizaciones disponibles..." -Level INFO
    Write-Host "`nBuscando actualizaciones disponibles..." -ForegroundColor Cyan
    winget upgrade

    if (Confirm-Action "¿Desea instalar TODAS las actualizaciones disponibles?") {
        Invoke-ConElevacion -Nombre "Actualizar todos los programas" -Accion {
            winget upgrade --all --accept-source-agreements --accept-package-agreements
            Write-Log "Actualización completada." -Level SUCCESS
        }
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  13. INSTALAR PROGRAMA
# ─────────────────────────────────────────────────────────────
function Instalar-Programa {
    $programa = Read-Host "Ingrese el nombre del programa (ej: vlc, 7zip, chrome)"
    if ([string]::IsNullOrWhiteSpace($programa)) { return }

    Write-Host "`nBuscando '$programa' en winget..." -ForegroundColor Cyan
    winget search $programa

    if (Confirm-Action "¿Instalar '$programa'?") {
        Invoke-ConElevacion -Nombre "Instalar $programa" -Accion {
            winget install $programa --accept-source-agreements --accept-package-agreements
            Write-Log "Programa '$programa' instalado." -Level SUCCESS
        }
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  14. DESINSTALAR PROGRAMA
# ─────────────────────────────────────────────────────────────
function Desinstalar-Programa {
    Write-Host "`nCargando programas instalados..." -ForegroundColor Cyan

    $programas = Get-Package | Where-Object { $_.ProviderName -eq "Programs" -or $_.ProviderName -eq "msi" } |
        Select-Object Name, Version, @{N="Proveedor";E={$_.ProviderName}} |
        Sort-Object Name

    $sel = $programas | Out-GridView -Title "Seleccione el programa a desinstalar" -PassThru
    if ($null -eq $sel) { return }

    if (-not (Confirm-Action "¿Desinstalar '$($sel.Name)'?")) { return }

    Invoke-ConElevacion -Nombre "Desinstalar $($sel.Name)" -Accion {
        winget uninstall $sel.Name --accept-source-agreements
        Write-Log "Programa '$($sel.Name)' desinstalado." -Level SUCCESS
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  15. GESTIONAR SERVICIOS
# ─────────────────────────────────────────────────────────────
function Gestionar-Servicios {
    do {
        $servicios = Get-Service | Select-Object DisplayName, Name, Status, StartType |
            Sort-Object DisplayName

        $sel = $servicios | Out-GridView -Title "Seleccione un servicio (cierre para volver)" -PassThru
        if ($null -eq $sel) { break }

        $accion = @("Iniciar","Detener","Reiniciar","Cambiar inicio (Automático)","Cambiar inicio (Manual)","Cambiar inicio (Deshabilitado)") |
            Out-GridView -Title "Acción para '$($sel.DisplayName)'" -PassThru
        if ($null -eq $accion) { continue }

        Invoke-ConElevacion -Nombre "$accion en $($sel.DisplayName)" -Accion {
            switch ($accion) {
                "Iniciar"                         { Start-Service -Name $sel.Name -ErrorAction Stop }
                "Detener"                         { Stop-Service  -Name $sel.Name -Force -ErrorAction Stop }
                "Reiniciar"                       { Restart-Service -Name $sel.Name -Force -ErrorAction Stop }
                "Cambiar inicio (Automático)"     { Set-Service -Name $sel.Name -StartupType Automatic }
                "Cambiar inicio (Manual)"         { Set-Service -Name $sel.Name -StartupType Manual }
                "Cambiar inicio (Deshabilitado)"  { Set-Service -Name $sel.Name -StartupType Disabled }
            }
        }
    } while ($true)
}

# ─────────────────────────────────────────────────────────────
#  17. OPTIMIZAR SISTEMA
# ─────────────────────────────────────────────────────────────
function Optimizar-Sistema {
    if (-not (Confirm-Action "¿Aplicar optimizaciones al sistema?")) { return }

    Invoke-ConElevacion -Nombre "Optimizar sistema" -Accion {
        Write-Log "Ajustando plan de energía a Alto Rendimiento..." -Level INFO
        powercfg /setactive SCHEME_MIN

        Write-Log "Deshabilitando efectos visuales innecesarios..." -Level INFO
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "VisualFXSetting" -Value 2

        Write-Log "Limpiando archivos temporales del sistema..." -Level INFO
        $rutas = @(
            "$env:TEMP",
            "$env:SystemRoot\Temp",
            "$env:SystemRoot\Prefetch",
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
        )
        foreach ($ruta in $rutas) {
            if (Test-Path $ruta) {
                Remove-Item "$ruta\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Limpiado: $ruta" -Level INFO
            }
        }

        Write-Log "Deshabilitando programas de inicio innecesarios en el registro..." -Level INFO
        Write-Host "`n⚠ Abriendo Administrador de tareas — pestaña 'Inicio' para revisar manualmente." -ForegroundColor Yellow
        Start-Process "taskmgr"

        Write-Log "Optimización del sistema completada." -Level SUCCESS
        Write-Host "`n✔ Plan de energía: Alto Rendimiento activado." -ForegroundColor Green
        Write-Host "✔ Efectos visuales reducidos." -ForegroundColor Green
        Write-Host "✔ Archivos temporales eliminados." -ForegroundColor Green
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  18. LIMPIAR ARCHIVOS BASURA
# ─────────────────────────────────────────────────────────────
function Limpiar-Basura {
    Write-Log "Iniciando limpieza de archivos basura" -Level INFO

    $rutas = [ordered]@{
        "Temp del usuario"              = $env:TEMP
        "Temp del sistema"              = "$env:SystemRoot\Temp"
        "Prefetch de Windows"           = "$env:SystemRoot\Prefetch"
        "Caché de Internet Explorer"    = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
        "Miniaturas (Thumbnails)"       = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        "Papelera de reciclaje"         = $null   # manejo especial
    }

    $totalLiberado = 0

    foreach ($nombre in $rutas.Keys) {
        $ruta = $rutas[$nombre]
        if ($nombre -eq "Papelera de reciclaje") {
            $antes = (Get-ChildItem "C:\`$Recycle.Bin" -Recurse -Force -ErrorAction SilentlyContinue |
                      Measure-Object -Property Length -Sum).Sum
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            $totalLiberado += $antes
            Write-Log "Papelera vaciada: $(Format-Bytes $antes)" -Level INFO
            continue
        }
        if (Test-Path $ruta) {
            $antes = (Get-ChildItem $ruta -Recurse -File -ErrorAction SilentlyContinue |
                      Measure-Object -Property Length -Sum).Sum
            Remove-Item "$ruta\*" -Recurse -Force -ErrorAction SilentlyContinue
            $totalLiberado += $antes
            Write-Log "$nombre limpiado: $(Format-Bytes $antes)" -Level INFO
        }
    }

    Write-Host "`n✔ Espacio total liberado: $(Format-Bytes $totalLiberado)" -ForegroundColor Green
    Write-Log "Limpieza completada. Total liberado: $(Format-Bytes $totalLiberado)" -Level SUCCESS

    if (Confirm-Action "¿Ejecutar también el Liberador de espacio en disco de Windows (cleanmgr)?") {
        Start-Process "cleanmgr" -ArgumentList "/sageset:65535" -Wait
        Start-Process "cleanmgr" -ArgumentList "/sagerun:65535" -Wait
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  19. INFORMACIÓN DEL HARDWARE
# ─────────────────────────────────────────────────────────────
function Mostrar-Info {
    Write-Log "Recopilando información del hardware" -Level INFO

    Write-Host "`n=== SISTEMA OPERATIVO ===" -ForegroundColor Cyan
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host "  SO:       $($os.Caption) $($os.OSArchitecture)"
    Write-Host "  Versión:  $($os.Version)  Build: $($os.BuildNumber)"
    Write-Host "  Último boot: $($os.LastBootUpTime)"
    $uptime = (Get-Date) - $os.LastBootUpTime
    Write-Host "  Uptime:   $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"

    Write-Host "`n=== PROCESADOR ===" -ForegroundColor Cyan
    $cpu = Get-CimInstance Win32_Processor
    Write-Host "  Modelo:     $($cpu.Name)"
    Write-Host "  Núcleos:    $($cpu.NumberOfCores) físicos / $($cpu.NumberOfLogicalProcessors) lógicos"
    Write-Host "  Velocidad:  $($cpu.MaxClockSpeed) MHz"
    Write-Host "  Uso actual: $($cpu.LoadPercentage)%"

    Write-Host "`n=== MEMORIA RAM ===" -ForegroundColor Cyan
    $ram = Get-CimInstance Win32_PhysicalMemory
    $totalRam = ($ram | Measure-Object -Property Capacity -Sum).Sum
    Write-Host "  Total instalada: $(Format-Bytes $totalRam)"
    $ram | ForEach-Object {
        Write-Host ("  Slot {0}: {1} {2} @ {3} MHz  SN:{4}" -f `
            $_.DeviceLocator, (Format-Bytes $_.Capacity), $_.MemoryType, $_.Speed, $_.SerialNumber)
    }
    $osRam = Get-CimInstance Win32_OperatingSystem
    Write-Host "  RAM libre:  $(Format-Bytes ($osRam.FreePhysicalMemory * 1KB))"

    Write-Host "`n=== DISCOS ===" -ForegroundColor Cyan
    Get-CimInstance Win32_DiskDrive | ForEach-Object {
        Write-Host ("  {0}  {1}  Tipo:{2}  SN:{3}" -f $_.Model, (Format-Bytes $_.Size), $_.MediaType, $_.SerialNumber)
    }

    Write-Host "`n=== GPU ===" -ForegroundColor Cyan
    Get-CimInstance Win32_VideoController | ForEach-Object {
        Write-Host "  $($_.Name)  VRAM: $(Format-Bytes $_.AdapterRAM)  Driver: $($_.DriverVersion)"
    }

    Write-Host "`n=== PLACA BASE ===" -ForegroundColor Cyan
    $mb = Get-CimInstance Win32_BaseBoard
    Write-Host "  Fabricante: $($mb.Manufacturer)  Modelo: $($mb.Product)  SN: $($mb.SerialNumber)"

    Write-Host "`n=== BIOS ===" -ForegroundColor Cyan
    $bios = Get-CimInstance Win32_BIOS
    Write-Host "  Fabricante: $($bios.Manufacturer)  Versión: $($bios.SMBIOSBIOSVersion)  Fecha: $($bios.ReleaseDate)"

    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  20. INFORMACIÓN DE DRIVERS
# ─────────────────────────────────────────────────────────────
function Mostrar-Drivers {
    Write-Log "Listando drivers" -Level INFO

    Write-Host "`n=== DRIVERS CON PROBLEMAS ===" -ForegroundColor Red
    $problemas = Get-WmiObject Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } |
        Select-Object Name, ConfigManagerErrorCode, Description
    if ($problemas) { $problemas | Format-Table -AutoSize }
    else { Write-Host "  ✔ No se detectaron problemas en drivers." -ForegroundColor Green }

    Write-Host "`n=== TODOS LOS DRIVERS FIRMADOS ===" -ForegroundColor Cyan
    $drivers = Get-WmiObject Win32_PnPSignedDriver |
        Where-Object { $_.DeviceName } |
        Select-Object @{N="Dispositivo";E={$_.DeviceName}},
                      @{N="Fabricante";E={$_.Manufacturer}},
                      @{N="Versión";E={$_.DriverVersion}},
                      @{N="Fecha";E={$_.DriverDate}} |
        Sort-Object Dispositivo

    $drivers | Out-GridView -Title "Drivers instalados"

    if (Confirm-Action "¿Abrir DirectX Diagnostic Tool (dxdiag) para reporte detallado?") {
        Start-Process dxdiag
    }
}

# ─────────────────────────────────────────────────────────────
#  21. MONITOR DE RECURSOS EN TIEMPO REAL
# ─────────────────────────────────────────────────────────────
function Monitor-Recursos {
    Write-Host "`n=== MONITOR DE RECURSOS EN TIEMPO REAL ===" -ForegroundColor Cyan
    Write-Host "Presione CTRL+C para detener el monitoreo.`n" -ForegroundColor DarkGray

    $iteraciones = 0
    try {
        while ($true) {
            $iteraciones++
            $cpu = (Get-CimInstance Win32_Processor).LoadPercentage
            $os  = Get-CimInstance Win32_OperatingSystem
            $ramTotal = $os.TotalVisibleMemorySize * 1KB
            $ramLibre = $os.FreePhysicalMemory * 1KB
            $ramUsada = $ramTotal - $ramLibre
            $ramPct   = [math]::Round(($ramUsada / $ramTotal) * 100, 1)

            $cpuBar = "█" * [math]::Floor($cpu / 5) + "░" * (20 - [math]::Floor($cpu / 5))
            $ramBar = "█" * [math]::Floor($ramPct / 5) + "░" * (20 - [math]::Floor($ramPct / 5))

            $cpuColor = if ($cpu -gt 80) { "Red" } elseif ($cpu -gt 50) { "Yellow" } else { "Green" }
            $ramColor = if ($ramPct -gt 80) { "Red" } elseif ($ramPct -gt 60) { "Yellow" } else { "Green" }

            Write-Host ("`r  CPU [$cpuBar] {0,3}%   RAM [$ramBar] {1,3}%  ({2} usada)   " -f `
                $cpu, $ramPct, (Format-Bytes $ramUsada)) -NoNewline -ForegroundColor $cpuColor

            if ($iteraciones % 10 -eq 0) {
                Write-Host ""
                Write-Host "`n=== TOP 5 PROCESOS POR CPU ===" -ForegroundColor Cyan
                Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 |
                    Select-Object @{N="Proceso";E={$_.Name}},
                                  @{N="CPU(s)";E={[math]::Round($_.CPU,1)}},
                                  @{N="RAM";E={ Format-Bytes $_.WorkingSet64 }},
                                  Id |
                    Format-Table -AutoSize
            }

            Start-Sleep -Seconds 2
        }
    } catch {
        Write-Host "`nMonitoreo detenido." -ForegroundColor Yellow
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  22. GENERAR REPORTE HTML
# ─────────────────────────────────────────────────────────────
function Generar-ReporteHTML {
    Write-Log "Generando reporte HTML completo..." -Level INFO
    Show-Progress "Reporte" "Recopilando datos del sistema..." 5

    $fecha      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $os         = Get-CimInstance Win32_OperatingSystem
    $cpu        = Get-CimInstance Win32_Processor
    $ram        = Get-CimInstance Win32_PhysicalMemory
    $discos     = Get-CimInstance Win32_DiskDrive
    $gpu        = Get-CimInstance Win32_VideoController
    $mb         = Get-CimInstance Win32_BaseBoard
    $bios       = Get-CimInstance Win32_BIOS
    $adaptRed   = Get-NetAdapter | Where-Object Status -eq 'Up'
    $ipConfig   = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway }
    $uptime     = (Get-Date) - $os.LastBootUpTime

    Show-Progress "Reporte" "Calculando RAM..." 20
    $totalRam   = ($ram | Measure-Object -Property Capacity -Sum).Sum
    $ramLibre   = $os.FreePhysicalMemory * 1KB
    $ramUsada   = $totalRam - $ramLibre
    $ramPct     = [math]::Round(($ramUsada / $totalRam) * 100, 1)

    Show-Progress "Reporte" "Analizando volúmenes..." 35
    $volumenes  = Get-Volume | Where-Object { $_.DriveLetter }

    Show-Progress "Reporte" "Verificando drivers con problemas..." 50
    $driversProb = Get-WmiObject Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }

    Show-Progress "Reporte" "Revisando servicios críticos..." 65
    $serviciosCrit = @("wuauserv","WinDefend","MpsSvc","EventLog","Dnscache","LanmanServer") |
        ForEach-Object { Get-Service -Name $_ -ErrorAction SilentlyContinue }

    Show-Progress "Reporte" "Revisando top procesos..." 75
    $topProcesos = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10

    Show-Progress "Reporte" "Construyendo HTML..." 85

    function Row { param($k,$v) "<tr><td class='k'>$k</td><td>$v</td></tr>" }
    function Section { param($t) "<h2>$t</h2>" }

    $volHtml = ($volumenes | ForEach-Object {
        $pct = if ($_.Size -gt 0) { [math]::Round(($_.SizeRemaining / $_.Size)*100,1) } else { 0 }
        $color = if ($pct -lt 10) { "#e74c3c" } elseif ($pct -lt 20) { "#f39c12" } else { "#27ae60" }
        "<tr><td>$($_.DriveLetter):</td><td>$($_.FileSystemLabel)</td><td>$($_.FileSystem)</td>
         <td>$(Format-Bytes $_.SizeRemaining)</td><td>$(Format-Bytes $_.Size)</td>
         <td><div style='background:#eee;border-radius:4px;height:14px'>
         <div style='background:$color;width:$($pct)%;height:14px;border-radius:4px'></div></div>$pct%</td></tr>"
    }) -join ""

    $procHtml = ($topProcesos | ForEach-Object {
        "<tr><td>$($_.Name)</td><td>$($_.Id)</td><td>$(Format-Bytes $_.WorkingSet64)</td><td>$([math]::Round($_.CPU,1))</td></tr>"
    }) -join ""

    $svcHtml = ($serviciosCrit | ForEach-Object {
        if ($null -eq $_) { return }
        $color = if ($_.Status -eq 'Running') { "#27ae60" } else { "#e74c3c" }
        "<tr><td>$($_.DisplayName)</td><td style='color:$color;font-weight:bold'>$($_.Status)</td><td>$($_.StartType)</td></tr>"
    }) -join ""

    $drvProb = if ($driversProb) {
        ($driversProb | ForEach-Object { "<tr><td>$($_.Name)</td><td style='color:red'>Error $($_.ConfigManagerErrorCode)</td></tr>" }) -join ""
    } else { "<tr><td colspan='2' style='color:green'>✔ Sin problemas detectados</td></tr>" }

    $html = @"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Reporte del Sistema — $($os.CSName) — $fecha</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Segoe UI', sans-serif; background: #f0f2f5; color: #333; padding: 24px; }
  h1 { background: linear-gradient(135deg, #1a237e, #283593); color: white;
       padding: 20px 28px; border-radius: 10px; margin-bottom: 24px; font-size: 1.6em; }
  h1 span { font-size: 0.7em; font-weight: normal; opacity: 0.85; display:block; margin-top:4px; }
  h2 { font-size: 1.1em; color: #1a237e; margin: 28px 0 10px;
       border-left: 4px solid #3949ab; padding-left: 10px; text-transform: uppercase; letter-spacing:.5px; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 20px; }
  .card { background: white; border-radius: 10px; padding: 20px;
          box-shadow: 0 2px 8px rgba(0,0,0,.08); }
  table { width: 100%; border-collapse: collapse; font-size: .88em; }
  th { background: #3949ab; color: white; padding: 8px 12px; text-align: left; }
  td { padding: 7px 12px; border-bottom: 1px solid #eee; vertical-align: middle; }
  tr:last-child td { border-bottom: none; }
  tr:hover td { background: #f5f7ff; }
  td.k { color: #555; font-weight: 600; width: 45%; }
  .badge { display:inline-block; padding:2px 10px; border-radius:99px; font-size:.8em; font-weight:600; color:white; }
  .ok   { background:#27ae60; }
  .warn { background:#f39c12; }
  .err  { background:#e74c3c; }
  footer { margin-top: 32px; text-align:center; color:#aaa; font-size:.8em; }
</style>
</head>
<body>
<h1>🖥 Reporte del Sistema — $($os.CSName)
  <span>Generado: $fecha &nbsp;|&nbsp; Usuario: $env:USERNAME &nbsp;|&nbsp; v$($Script:Config.Version)</span>
</h1>

<div class="grid">
<div class="card">
$(Section "Sistema Operativo")
<table>
$(Row "SO" "$($os.Caption) $($os.OSArchitecture)")
$(Row "Versión" "$($os.Version) (Build $($os.BuildNumber))")
$(Row "Último inicio" "$($os.LastBootUpTime)")
$(Row "Uptime" "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m")
$(Row "Directorio Windows" "$($os.WindowsDirectory)")
$(Row "Zona horaria" "$(Get-TimeZone | Select-Object -ExpandProperty DisplayName)")
</table>
</div>

<div class="card">
$(Section "Procesador")
<table>
$(Row "Modelo" "$($cpu.Name)")
$(Row "Núcleos físicos" "$($cpu.NumberOfCores)")
$(Row "Núcleos lógicos" "$($cpu.NumberOfLogicalProcessors)")
$(Row "Velocidad máx." "$($cpu.MaxClockSpeed) MHz")
$(Row "Socket" "$($cpu.SocketDesignation)")
$(Row "Uso actual" "<span class='badge $(if($cpu.LoadPercentage -gt 80){'err'}elseif($cpu.LoadPercentage -gt 50){'warn'}else{'ok'})'>$($cpu.LoadPercentage)%</span>")
</table>
</div>

<div class="card">
$(Section "Memoria RAM")
<table>
$(Row "Total instalada" "$(Format-Bytes $totalRam)")
$(Row "Usada" "$(Format-Bytes $ramUsada) ($ramPct%)")
$(Row "Libre" "$(Format-Bytes $ramLibre)")
$(Row "Módulos" "$($ram.Count)")
</table>
</div>

<div class="card">
$(Section "Placa Base y BIOS")
<table>
$(Row "Fabricante MB" "$($mb.Manufacturer)")
$(Row "Modelo MB" "$($mb.Product)")
$(Row "SN Placa" "$($mb.SerialNumber)")
$(Row "BIOS Fabricante" "$($bios.Manufacturer)")
$(Row "BIOS Versión" "$($bios.SMBIOSBIOSVersion)")
$(Row "BIOS Fecha" "$($bios.ReleaseDate)")
</table>
</div>

<div class="card">
$(Section "Tarjeta Gráfica")
<table>
$(($gpu | ForEach-Object { Row $_.Name "VRAM: $(Format-Bytes $_.AdapterRAM)  Driver: $($_.DriverVersion)" }) -join "")
</table>
</div>

<div class="card">
$(Section "Red")
<table>
$(($adaptRed | ForEach-Object { Row $_.Name "$($_.Status) — $($_.LinkSpeed) — MAC: $($_.MacAddress)" }) -join "")
$(($ipConfig | ForEach-Object { Row "IP ($($_.InterfaceAlias))" "$($_.IPv4Address.IPAddress)" }) -join "")
</table>
</div>
</div>

$(Section "Almacenamiento — Volúmenes")
<div class="card">
<table>
<tr><th>Unidad</th><th>Nombre</th><th>Sistema</th><th>Libre</th><th>Total</th><th>Uso</th></tr>
$volHtml
</table>
</div>

$(Section "Top 10 Procesos por RAM")
<div class="card">
<table>
<tr><th>Proceso</th><th>PID</th><th>RAM</th><th>CPU(s)</th></tr>
$procHtml
</table>
</div>

$(Section "Servicios Críticos")
<div class="card">
<table>
<tr><th>Servicio</th><th>Estado</th><th>Inicio</th></tr>
$svcHtml
</table>
</div>

$(Section "Drivers con Problemas")
<div class="card">
<table>
<tr><th>Dispositivo</th><th>Estado</th></tr>
$drvProb
</table>
</div>

<footer>Generado por Herramienta de Mantenimiento Pro v$($Script:Config.Version) — $fecha</footer>
</body>
</html>
"@

    Write-Progress -Completed -Activity "Reporte"

    $timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $reportPath = Join-Path $Script:Config.ReportDir "reporte_$($os.CSName)_$timestamp.html"
    $html | Out-File -FilePath $reportPath -Encoding UTF8

    Write-Log "Reporte generado en: $reportPath" -Level SUCCESS
    Write-Host "`n✔ Reporte guardado en:`n  $reportPath" -ForegroundColor Green

    if (Confirm-Action "¿Abrir el reporte en el navegador?") {
        Start-Process $reportPath
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  23. ESCANEAR CON WINDOWS DEFENDER
# ─────────────────────────────────────────────────────────────
function Escanear-Defender {
    $tipo = @("Escaneo rápido","Escaneo completo","Escaneo personalizado") |
        Out-GridView -Title "Tipo de escaneo" -PassThru
    if ($null -eq $tipo) { return }

    Invoke-ConElevacion -Nombre "Windows Defender — $tipo" -Accion {
        switch ($tipo) {
            "Escaneo rápido"       { Start-MpScan -ScanType QuickScan }
            "Escaneo completo"     { Start-MpScan -ScanType FullScan }
            "Escaneo personalizado" {
                $ruta = Read-Host "Ingrese la ruta a escanear (ej: C:\Users)"
                Start-MpScan -ScanType CustomScan -ScanPath $ruta
            }
        }
        Write-Log "Escaneo de Defender completado." -Level SUCCESS
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  24. GESTIONAR TAREAS PROGRAMADAS
# ─────────────────────────────────────────────────────────────
function Gestionar-TareasProgramadas {
    $tareas = Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' } |
        Select-Object TaskName, TaskPath, State,
            @{N="Próxima ejecución";E={ (Get-ScheduledTaskInfo $_.TaskName -ErrorAction SilentlyContinue).NextRunTime }} |
        Sort-Object TaskPath

    $sel = $tareas | Out-GridView -Title "Tareas Programadas activas (cierre para volver)" -PassThru
    if ($null -eq $sel) { return }

    $accion = @("Ejecutar ahora","Deshabilitar","Ver detalles") |
        Out-GridView -Title "Acción para '$($sel.TaskName)'" -PassThru
    if ($null -eq $accion) { return }

    Invoke-ConElevacion -Nombre "$accion tarea '$($sel.TaskName)'" -Accion {
        switch ($accion) {
            "Ejecutar ahora" { Start-ScheduledTask -TaskName $sel.TaskName -TaskPath $sel.TaskPath }
            "Deshabilitar"   {
                if (Confirm-Action "¿Deshabilitar la tarea '$($sel.TaskName)'?") {
                    Disable-ScheduledTask -TaskName $sel.TaskName -TaskPath $sel.TaskPath
                }
            }
            "Ver detalles"   { Get-ScheduledTask -TaskName $sel.TaskName | Format-List * }
        }
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  25. AUDITORÍA DE USUARIOS
# ─────────────────────────────────────────────────────────────
function Auditoria-Usuarios {
    Write-Log "Auditoría de usuarios iniciada" -Level INFO

    Write-Host "`n=== USUARIOS LOCALES ===" -ForegroundColor Cyan
    Get-LocalUser | Select-Object Name, Enabled, LastLogon,
        @{N="Contraseña expira";E={$_.PasswordExpires}},
        @{N="Admin";E={ (Get-LocalGroupMember "Administrators" -ErrorAction SilentlyContinue).Name -contains "$(env:COMPUTERNAME)\$($_.Name)" }} |
        Format-Table -AutoSize

    Write-Host "`n=== MIEMBROS DEL GRUPO ADMINISTRADORES ===" -ForegroundColor Cyan
    Get-LocalGroupMember -Group "Administrators" | Format-Table -AutoSize

    Write-Host "`n=== SESIONES ACTIVAS ===" -ForegroundColor Cyan
    query user 2>$null

    Write-Host "`n=== ÚLTIMOS 20 EVENTOS DE INICIO DE SESIÓN ===" -ForegroundColor Cyan
    Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 20 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated,
            @{N="Usuario";E={$_.Properties[5].Value}},
            @{N="Tipo";E={$_.Properties[8].Value}},
            @{N="IP";E={$_.Properties[18].Value}} |
        Format-Table -AutoSize

    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  26. HACER RESPALDO
# ─────────────────────────────────────────────────────────────
function Hacer-Respaldo {
    $tipoRespaldo = @(
        "Respaldo completo del sistema (wbadmin)",
        "Respaldo de carpeta específica (robocopy)",
        "Punto de restauración del sistema"
    ) | Out-GridView -Title "Tipo de respaldo" -PassThru
    if ($null -eq $tipoRespaldo) { return }

    switch ($tipoRespaldo) {
        "Respaldo completo del sistema (wbadmin)" {
            Write-Host "`nVolúmenes disponibles para destino:" -ForegroundColor Cyan
            $volDest = Get-Volume | Where-Object { $_.DriveLetter } |
                Select-Object @{N="Unidad";E={"$($_.DriveLetter):"}},
                              @{N="Etiqueta";E={$_.FileSystemLabel}},
                              @{N="Libre";E={ Format-Bytes $_.SizeRemaining }} |
                Out-GridView -Title "Seleccione unidad de destino" -PassThru
            if ($null -eq $volDest) { return }

            if (Confirm-Action "¿Iniciar respaldo completo del sistema hacia $($volDest.Unidad)?") {
                Invoke-ConElevacion -Nombre "Respaldo completo" -Accion {
                    Write-Log "Iniciando respaldo hacia $($volDest.Unidad)" -Level INFO
                    wbadmin start backup -backuptarget:"$($volDest.Unidad)" -include:C: -allCritical -quiet
                    Write-Log "Respaldo completado." -Level SUCCESS
                }
            }
        }
        "Respaldo de carpeta específica (robocopy)" {
            $origen  = Read-Host "Ruta de origen (ej: C:\Users\$env:USERNAME\Documents)"
            $destino = Read-Host "Ruta de destino (ej: D:\Respaldo)"
            if (-not (Test-Path $origen)) { Write-Host "Ruta de origen no existe." -ForegroundColor Red; return }

            Invoke-ConElevacion -Nombre "Robocopy $origen → $destino" -Accion {
                Write-Log "Robocopy: $origen → $destino" -Level INFO
                robocopy $origen $destino /MIR /Z /W:5 /R:3 /LOG:"$($Script:Config.LogDir)\robocopy_$(Get-Date -Format 'yyyyMMdd_HHmm').log"
                Write-Log "Robocopy completado." -Level SUCCESS
            }
        }
        "Punto de restauración del sistema" {
            $desc = "MantenimientoPro_$(Get-Date -Format 'yyyyMMdd_HHmm')"
            Invoke-ConElevacion -Nombre "Crear punto de restauración" -Accion {
                Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
                Checkpoint-Computer -Description $desc -RestorePointType "MODIFY_SETTINGS"
                Write-Log "Punto de restauración creado: $desc" -Level SUCCESS
                Write-Host "`n✔ Punto de restauración creado: $desc" -ForegroundColor Green
            }
        }
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  28. VER LOG DE SESIÓN
# ─────────────────────────────────────────────────────────────
function Ver-Log {
    Write-Host "`n=== LOG DE ESTA SESIÓN ===" -ForegroundColor Cyan
    Write-Host "Archivo: $($Script:Config.LogFile)`n" -ForegroundColor DarkGray
    Get-Content $Script:Config.LogFile | ForEach-Object {
        if ($_ -match '\[ERROR\]')   { Write-Host $_ -ForegroundColor Red }
        elseif ($_ -match '\[WARN\]') { Write-Host $_ -ForegroundColor Yellow }
        elseif ($_ -match '\[SUCCESS\]') { Write-Host $_ -ForegroundColor Green }
        else { Write-Host $_ -ForegroundColor Gray }
    }
    Pause-Screen
}

# ─────────────────────────────────────────────────────────────
#  PUNTO DE ENTRADA
# ─────────────────────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Este script requiere privilegios de administrador."
    Write-Host "Relanzando con privilegios elevados..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Initialize-Environment
Show-Menu
