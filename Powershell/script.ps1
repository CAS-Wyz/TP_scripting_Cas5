# --- Configuration des chemins ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pathA = Join-Path $scriptDir "env_A"
$pathB = Join-Path $scriptDir "env_B"
$logFile = Join-Path $scriptDir "env_B\sync_log.txt"

$OutputEncoding = [System.Text.Encoding]::UTF8
$stats = @{ Copies = 0; Conflits = 0; Proteges = 0; Ignores = 0 }

# --- FONCTIONS DE SUPPORT ---
function Get-Metadata($filePath) {
    $metaPath = "$filePath.meta"
    if (Test-Path $metaPath) {
        $content = Get-Content $metaPath -Raw | ConvertFrom-StringData
        return @{ version = [int]$content.version }
    }
    return $null
}

function Write-SyncLog($file, $status, $reason) {
    $logLine = "{0,-40} | {1,-25} | {2}" -f $file, $status, $reason
    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $logLine"
    $logEntry | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# --- INITIALISATION DU LOG ---
"`n" + ("="*105) | Out-File -FilePath $logFile -Append -Encoding UTF8
"--- SESSION : $(Get-Date) ---" | Out-File -FilePath $logFile -Append -Encoding UTF8
Write-SyncLog "FICHIER" "STATUT" "JUSTIFICATION"

# --- CHARGEMENT DES LISTES DE PROTECTION ---
$protFileA = Join-Path $pathA "protected_files.txt"
$protFileB = Join-Path $pathB "protected_files.txt"

$protectedListA = if (Test-Path $protFileA) { Get-Content $protFileA } else { @() }
$protectedListB = if (Test-Path $protFileB) { Get-Content $protFileB } else { @() }

# --- ANALYSE DES FICHIERS ---
$filesA = Get-ChildItem -Path $pathA -Recurse -File | Where-Object { $_.Extension -ne ".meta" -and $_.Name -ne "protected_files.txt" }
$filesB = Get-ChildItem -Path $pathB -Recurse -File | Where-Object { $_.Extension -ne ".meta" -and $_.Name -ne "protected_files.txt" }

$allPaths = @()
if ($filesA) { $filesA | ForEach-Object { $allPaths += $_.FullName.Replace($pathA, "").TrimStart('\') } }
if ($filesB) { $filesB | ForEach-Object { $allPaths += $_.FullName.Replace($pathB, "").TrimStart('\') } }
$allPaths = $allPaths | Select-Object -Unique

# --- BOUCLE DE SYNCHRONISATION ---
foreach ($relPath in $allPaths) {
    $fullA = Join-Path $pathA $relPath
    $fullB = Join-Path $pathB $relPath

    # --- ÉTAPE PRIORITAIRE : VÉRIFICATION DE PROTECTION ---
    # Si le fichier est dans la liste A OU dans la liste B, on bloque tout.
    if ($protectedListA -contains $relPath -or $protectedListB -contains $relPath) {
        Write-SyncLog $relPath "SYNCHRO REFUSEE" "Fichier protege (present dans protected_files.txt)"
        $stats.Proteges++
        continue
    }

    $existsA = Test-Path $fullA
    $existsB = Test-Path $fullB

    # --- CAS 1 : FICHIER UNIQUE ---
    if ($existsA -and -not $existsB) {
        Copy-Item $fullA $fullB -Force
        if (Test-Path "$fullA.meta") { Copy-Item "$fullA.meta" "$fullB.meta" -Force }
        Write-SyncLog $relPath "COPIE A -> B" "Initialisation nouveau fichier"
        $stats.Copies++
        continue
    }
    
    if ($existsB -and -not $existsA) {
        Copy-Item $fullB $fullA -Force
        if (Test-Path "$fullB.meta") { Copy-Item "$fullB.meta" "$fullA.meta" -Force }
        Write-SyncLog $relPath "COPIE B -> A" "Initialisation nouveau fichier"
        $stats.Copies++
        continue
    }

    # --- CAS 2 : PRESENT DES DEUX COTES ---
    $metaA = Get-Metadata $fullA
    $metaB = Get-Metadata $fullB
    $dateA = (Get-Item $fullA).LastWriteTime
    $dateB = (Get-Item $fullB).LastWriteTime

    # Vérification si un .meta manque
    if ($null -eq $metaA -or $null -eq $metaB) {
        Write-SyncLog $relPath "CONFLIT" "Metadonnees (.meta) manquantes"
        $stats.Conflits++
        continue
    }

    # LOGIQUE DE COMPARAISON DES VERSIONS
    if ($metaA.version -gt $metaB.version) {
        Copy-Item $fullA $fullB -Force
        Copy-Item "$fullA.meta" "$fullB.meta" -Force
        Write-SyncLog $relPath "COPIE A -> B" "Mise a jour vers v$($metaA.version)"
        $stats.Copies++
    }
    elseif ($metaB.version -gt $metaA.version) {
        Copy-Item $fullB $fullA -Force
        Copy-Item "$fullB.meta" "$fullA.meta" -Force
        Write-SyncLog $relPath "COPIE B -> A" "Mise a jour vers v$($metaB.version)"
        $stats.Copies++
    }
    else {
        # Versions .meta égales : vérification de la date de modification
        $diffSec = [math]::Abs(($dateA - $dateB).TotalSeconds)
        
        if ($diffSec -gt 2) {
            Write-SyncLog $relPath "CONFLIT" "Contenu modifie mais pas le fichier .meta"
            $stats.Conflits++
        } else {
            Write-SyncLog $relPath "IGNORE" "Versions et contenus identiques"
            $stats.Ignores++
        }
    }
}

# --- RÉSUMÉ FINAL ---
$summary = "RESUME | Copies: $($stats.Copies) | Conflits: $($stats.Conflits) | Proteges: $($stats.Proteges) | Ignores: $($stats.Ignores)"
$summary | Out-File -FilePath $logFile -Append -Encoding UTF8
Write-Host $summary -ForegroundColor Cyan
Write-Host "Synchro terminee. Logs disponibles : $logFile" -ForegroundColor Green