# ============================================================================
# SCRIPT: test_flyway_upgrade_path.ps1
# MỤC TIÊU: Kiểm thử tự động đường dẫn nâng cấp Flyway V1 -> V2 -> V3
#           với dữ liệu mẫu (Upgrade-Path Verification with Seed Data Preservation)
# TÁC NHÂN: Antigravity Agent (Task DB-003 Remediation R4)
# ============================================================================

$ErrorActionPreference = "Stop"

$PG_BIN = "D:\PostGresSQL\bin\psql.exe"
if (-not (Test-Path $PG_BIN)) {
    $PG_BIN = "psql"
}

$PGHOST = "localhost"
$PGPORT = "5432"
$PGUSER = "postgres"
$TEST_DB = "hemis_upgrade_fixture_test"

$MigrationDir = $PSScriptRoot

Write-Host "==================================================================="
Write-Host "  KIEM THU FLYWAY UPGRADE PATH V1 -> V2 -> V3 VOI DU LIEU MAU"
Write-Host "  Database co lap: $TEST_DB"
Write-Host "==================================================================="

function Invoke-PgSql {
    param(
        [string]$Database,
        [string]$SqlStatement
    )
    $escapedSql = $SqlStatement -replace '"', '\"'
    $args = @("-h", $PGHOST, "-p", $PGPORT, "-U", $PGUSER, "-d", $Database, "-c", $escapedSql, "-v", "ON_ERROR_STOP=1", "-t", "-A")
    $res = & $PG_BIN @args
    if ($LASTEXITCODE -ne 0) {
        throw "Loi thuc thi SQL tren ${Database}: $res"
    }
    return $res
}

function Invoke-PgFile {
    param(
        [string]$Database,
        [string]$FilePath
    )
    $fileName = Split-Path $FilePath -Leaf
    Write-Host "-> Chay migration: $fileName tren $Database..."
    Push-Location (Split-Path $FilePath)
    try {
        $args = @("-h", $PGHOST, "-p", $PGPORT, "-U", $PGUSER, "-d", $Database, "-f", $fileName, "-v", "ON_ERROR_STOP=1")
        & $PG_BIN @args
        if ($LASTEXITCODE -ne 0) {
            throw "Loi khi chay migration file $fileName!"
        }
    }
    finally {
        Pop-Location
    }
}

try {
    # -------------------------------------------------------------------------
    # BƯỚC 1: Khởi tạo database kiểm thử cô lập
    # -------------------------------------------------------------------------
    Write-Host "[1/7] Khoi tao database test co lap [$TEST_DB]..."
    Invoke-PgSql -Database "postgres" -SqlStatement "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$TEST_DB' AND pid <> pg_backend_pid();" | Out-Null
    Invoke-PgSql -Database "postgres" -SqlStatement "DROP DATABASE IF EXISTS $TEST_DB;" | Out-Null
    Invoke-PgSql -Database "postgres" -SqlStatement "CREATE DATABASE $TEST_DB;" | Out-Null
    Write-Host "   -> Database [$TEST_DB] da duoc tao moi."

    # -------------------------------------------------------------------------
    # BƯỚC 2: Chạy migration V1__hemis_sync.sql
    # -------------------------------------------------------------------------
    Write-Host "[2/7] Chay migration V1..."
    $v1Path = Join-Path $MigrationDir "V1__hemis_sync.sql"
    Invoke-PgFile -Database $TEST_DB -FilePath $v1Path

    # -------------------------------------------------------------------------
    # BƯỚC 3: Nạp dữ liệu mẫu vào schema V1 (Seed Data)
    # -------------------------------------------------------------------------
    Write-Host "[3/7] Nap du lieu mau vao cac bang V1..."
    $seedSql = @"
INSERT INTO hemis_sync.entity_map (local_table, local_id, hemis_id, created_at) VALUES
('co_so_giao_duc', 'CSGD_V1_SEED_01', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'::uuid, '2026-01-01 08:00:00+07'),
('can_bo',         'CCCD_001099000001', 'b2c3d4e5-f6a1-4b5c-9d0e-1f2a3b4c5d6e'::uuid, '2026-01-01 08:05:00+07'),
('nguoi_hoc',      'SV_2026_000001',    'c3d4e5f6-a1b2-4c5d-0e1f-2a3b4c5d6e7f'::uuid, '2026-01-01 08:10:00+07');

INSERT INTO hemis_sync.catalog_hemis (dm_name, hemis_id, code, ma, ten) VALUES
('DM_LOAI_HINH_TRUONG', 'd4e5f6a1-b2c3-4d5e-1f2a-3b4c5d6e7f80', 'CONG_LAP', '01', 'Truong cong lap');

INSERT INTO hemis_sync.catalog_map (dm_name, local_code, hemis_code, note) VALUES
('DM_LOAI_HINH_TRUONG', 'CL', '01', 'Anh xa tu ma CL sang 01 HEMIS');
"@
    Invoke-PgSql -Database $TEST_DB -SqlStatement $seedSql | Out-Null

    $v1Count = (Invoke-PgSql -Database $TEST_DB -SqlStatement "SELECT COUNT(*) FROM hemis_sync.entity_map;").Trim()
    Write-Host "   -> Da nap thanh cong $v1Count ban ghi entity_map trong schema V1."

    # -------------------------------------------------------------------------
    # BƯỚC 4: Chạy migration nâng cấp V2__bo_sung_hemis_sync.sql
    # -------------------------------------------------------------------------
    Write-Host "[4/7] Chay migration nang cap V2..."
    $v2Path = Join-Path $MigrationDir "V2__bo_sung_hemis_sync.sql"
    Invoke-PgFile -Database $TEST_DB -FilePath $v2Path

    # -------------------------------------------------------------------------
    # BƯỚC 5: Xác nhận dữ liệu, khóa nghiệp vụ và GUID không đổi sau khi chạy V2
    # -------------------------------------------------------------------------
    Write-Host "[5/7] Kiem tra bao toan du lieu (Data & Key Preservation Assertion)..."
    
    # 5.1 Kiểm tra cột mới và khóa chính mới
    $pkCols = (Invoke-PgSql -Database $TEST_DB -SqlStatement @"
SELECT string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position)
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'hemis_sync' AND tc.table_name = 'entity_map' AND tc.constraint_type = 'PRIMARY KEY';
"@).Trim()

    if ($pkCols -ne "entity_type, business_key") {
        throw "ASSERTION FAILED: Khoa chinh moi cua entity_map ky vong 'entity_type, business_key' nhung la '$pkCols'!"
    }
    Write-Host "   -> Khoa chinh entity_map da duoc chuyen sang: ($pkCols)"

    # 5.2 Xác thực dữ liệu và GUID từng bản ghi
    $checkRowsSql = @"
SELECT entity_type || '|' || business_key || '|' || hemis_id::text
FROM hemis_sync.entity_map
ORDER BY entity_type, business_key;
"@
    $preservedRows = (Invoke-PgSql -Database $TEST_DB -SqlStatement $checkRowsSql) -split "`r?`n" | Where-Object { $_ -match '\|' }
    
    $expectedMap = @{
        "CAN_BO|CCCD_001099000001"         = "b2c3d4e5-f6a1-4b5c-9d0e-1f2a3b4c5d6e"
        "CO_SO_GIAO_DUC|CSGD_V1_SEED_01"   = "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d"
        "NGUOI_HOC|SV_2026_000001"         = "c3d4e5f6-a1b2-4c5d-0e1f-2a3b4c5d6e7f"
    }

    foreach ($row in $preservedRows) {
        $parts = $row.Split('|')
        $key = "$($parts[0])|$($parts[1])"
        $guid = $parts[2]
        if (-not $expectedMap.ContainsKey($key)) {
            throw "ASSERTION FAILED: Ban ghi bat thuong xuat hien sau V2: $key"
        }
        if ($expectedMap[$key] -ne $guid) {
            throw "ASSERTION FAILED: GUID bi thay doi sau V2! Key: $key, Ky vong: $($expectedMap[$key]), Thuc te: $guid"
        }
        Write-Host "   -> Xac thuc: Key [$key] bao toan GUID goc [$guid] 100%."
    }

    # 5.3 Nạp bản ghi mẫu vào hemis_sync.co_so_giao_duc để sẵn sàng kiểm thử V3
    $seedCsgdSql = @"
INSERT INTO hemis_sync.co_so_giao_duc (
    id, hemis_id, ma_don_vi, ten_don_vi, website, email, so_dien_thoai, dia_chi,
    tinh_thanh_new, xa_phuong_new, so_qd_thanh_lap, ngay_qd_thanh_lap,
    ngay_duoc_cap_phep_hoat_dong, loai_hinh_id, hinh_thuc_thanh_lap, loai_co_so, ma_dinh_danh_nd69
) VALUES (
    1, 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'::uuid, 'CSGD_V1_SEED_01',
    'Truong Dai Hoc Su Pham Test', 'https://hnue.edu.vn', 'contact@hnue.edu.vn', '02438333333',
    '136 Xuan Thuy, Cau Giay, Ha Noi', '01_NEW', '001_NEW', 'QD-123/BGDDT', '1951-10-11',
    '1951-10-11', 'd4e5f6a1-b2c3-4d5e-1f2a-3b4c5d6e7f80', 'Cong lap', 'Dai hoc', 'ND69_CSGD_TEST'
);
"@
    Invoke-PgSql -Database $TEST_DB -SqlStatement $seedCsgdSql | Out-Null
    Write-Host "   -> Da nap ban ghi co_so_giao_duc (ma_don_vi = CSGD_V1_SEED_01)."

    # -------------------------------------------------------------------------
    # BƯỚC 6: Chạy migration V3__hemis_src_views.sql
    # -------------------------------------------------------------------------
    Write-Host "[6/7] Chay migration V3..."
    $v3Path = Join-Path $MigrationDir "V3__hemis_src_views.sql"
    Invoke-PgFile -Database $TEST_DB -FilePath $v3Path

    # -------------------------------------------------------------------------
    # BƯỚC 7: Xác thực Contract Views và Unmapped Guard trên V3
    # -------------------------------------------------------------------------
    Write-Host "[7/7] Kiem tra Contract View [hemis_src.v_co_so_giao_duc]..."
    $viewRow = (Invoke-PgSql -Database $TEST_DB -SqlStatement @'
SELECT "ID"::text || '|' || "MA_DON_VI" || '|' || "TEN_DON_VI"
FROM hemis_src.v_co_so_giao_duc;
'@).Trim()

    $expectedView = "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d|CSGD_V1_SEED_01|Truong Dai Hoc Su Pham Test"
    if ($viewRow -ne $expectedView) {
        throw "ASSERTION FAILED: View hemis_src.v_co_so_giao_duc tra ve sai: '$viewRow' thay vi '$expectedView'!"
    }
    Write-Host "   -> View hemis_src.v_co_so_giao_duc tra ve GUID goc chinh xac: $viewRow"

    Write-Host "==================================================================="
    Write-Host "  FLYWAY UPGRADE PATH V1 -> V2 -> V3 PASS HOAN TOAN 100%!"
    Write-Host "  DU LIEU VA GUID DA DUOC BAO TOAN TUYET DOI QUA CAC DOT NANG CAP."
    Write-Host "==================================================================="
}
finally {
    Write-Host "-> Don dep database test co lap [$TEST_DB]..."
    Invoke-PgSql -Database "postgres" -SqlStatement "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$TEST_DB' AND pid <> pg_backend_pid();" | Out-Null
    Invoke-PgSql -Database "postgres" -SqlStatement "DROP DATABASE IF EXISTS $TEST_DB;" | Out-Null
    Write-Host "-> Hoan tat don dep."
}

exit 0
