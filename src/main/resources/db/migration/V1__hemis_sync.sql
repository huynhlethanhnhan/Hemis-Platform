-- =====================================================================
-- V1 - Schema hemis_sync: vung lam viec cua Cong tich hop HEMIS
-- Khong dung chung voi schema nghiep vu (dwh) de co the trien khai doc lap.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. entity_map: anh xa khoa noi bo -> dinh danh GUID gui cho HEMIS
--    GUID sinh MOT LAN va giu co dinh, de HEMIS cap nhat dung ban ghi
--    qua nhieu dot dong bo.
-- ---------------------------------------------------------------------
CREATE TABLE entity_map (
    local_table   VARCHAR(100) NOT NULL,
    local_id      VARCHAR(100) NOT NULL,
    hemis_id      UUID         NOT NULL DEFAULT gen_random_uuid(),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_entity_map PRIMARY KEY (local_table, local_id),
    CONSTRAINT uq_entity_map_hemis_id UNIQUE (hemis_id)
);
COMMENT ON TABLE entity_map IS 'Anh xa khoa noi bo sang GUID gui cho HEMIS; GUID khong duoc thay doi';

-- ---------------------------------------------------------------------
-- 2. catalog_hemis: ban sao hon 175 danh muc dung chung cua HEMIS
-- ---------------------------------------------------------------------
CREATE TABLE catalog_hemis (
    id            BIGSERIAL    PRIMARY KEY,
    dm_name       VARCHAR(100) NOT NULL,   -- vi du: DM_DAN_TOC
    hemis_id      VARCHAR(36),             -- truong Id (Guid) cua ban ghi danh muc
    code          VARCHAR(100),            -- truong Code
    ma            VARCHAR(100),            -- truong MA_<TEN_DANH_MUC>
    ten           VARCHAR(500),            -- truong TEN_<TEN_DANH_MUC>
    is_public     BOOLEAN,
    is_deleted    BOOLEAN      NOT NULL DEFAULT false,
    modified      TIMESTAMPTZ,
    fetched_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    raw_json      JSONB,                   -- giu nguyen ban ghi goc de doi chieu
    CONSTRAINT uq_catalog_hemis UNIQUE (dm_name, ma)
);
CREATE INDEX ix_catalog_hemis_dm ON catalog_hemis (dm_name);
COMMENT ON TABLE catalog_hemis IS 'Ban sao danh muc dung chung tai ve tu API getDanhMucHemis';

-- ---------------------------------------------------------------------
-- 3. catalog_map: anh xa ma danh muc noi bo -> ma HEMIS
-- ---------------------------------------------------------------------
CREATE TABLE catalog_map (
    id            BIGSERIAL    PRIMARY KEY,
    dm_name       VARCHAR(100) NOT NULL,
    local_code    VARCHAR(100) NOT NULL,
    hemis_code    VARCHAR(100),            -- NULL = chua anh xa duoc (loi muc chan)
    note          VARCHAR(500),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_catalog_map UNIQUE (dm_name, local_code)
);
COMMENT ON COLUMN catalog_map.hemis_code IS 'NULL nghia la chua anh xa duoc - phai xu ly truoc khi gui';

-- ---------------------------------------------------------------------
-- 4. sync_batch: moi dot dong bo mot phan he
-- ---------------------------------------------------------------------
CREATE TABLE sync_batch (
    id              BIGSERIAL    PRIMARY KEY,
    ph              VARCHAR(50)  NOT NULL,  -- COSOGIAODUC, CANBO, HOCVIEN...
    api             VARCHAR(10)  NOT NULL,  -- db1, db3, db7...
    iks             UUID         NOT NULL,  -- ma phien ky so (k1 + k2)
    id_key          UUID         NOT NULL,  -- ma phien dong bo (tra cuu nhat ky)
    don_vi_id       UUID         NOT NULL,
    record_count    INT          NOT NULL DEFAULT 0,
    status          VARCHAR(30)  NOT NULL,  -- xem enum BatchStatus
    xml_path        VARCHAR(500),
    signed_xml_path VARCHAR(500),
    json_path       VARCHAR(500),
    payload_sha256  VARCHAR(64),
    signer_subject  VARCHAR(500),           -- X509SubjectName cua nguoi ky
    signed_at       TIMESTAMPTZ,
    sent_at         TIMESTAMPTZ,
    message         TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_sync_batch_iks UNIQUE (iks)
);
CREATE INDEX ix_sync_batch_status ON sync_batch (status, created_at DESC);
CREATE INDEX ix_sync_batch_ph ON sync_batch (ph, created_at DESC);

-- ---------------------------------------------------------------------
-- 5. sync_record: ban ghi thuoc tung dot
-- ---------------------------------------------------------------------
CREATE TABLE sync_record (
    id            BIGSERIAL    PRIMARY KEY,
    batch_id      BIGINT       NOT NULL REFERENCES sync_batch (id) ON DELETE CASCADE,
    entity        VARCHAR(100) NOT NULL,   -- vi du: _CO_SO_GIAO_DUC
    hemis_id      UUID,
    local_id      VARCHAR(100),
    valid         BOOLEAN      NOT NULL DEFAULT true,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX ix_sync_record_batch ON sync_record (batch_id);

-- ---------------------------------------------------------------------
-- 6. sync_error: loi theo tung ban ghi / tung truong
-- ---------------------------------------------------------------------
CREATE TABLE sync_error (
    id            BIGSERIAL    PRIMARY KEY,
    batch_id      BIGINT       REFERENCES sync_batch (id) ON DELETE CASCADE,
    entity        VARCHAR(100),
    local_id      VARCHAR(100),
    field         VARCHAR(100),
    rule_code     VARCHAR(50),             -- REQUIRED, MAX_LENGTH, CATALOG, CONDITIONAL...
    severity      VARCHAR(20)  NOT NULL DEFAULT 'BLOCK',  -- BLOCK | WARN
    message       TEXT         NOT NULL,
    owner_unit    VARCHAR(100),            -- don vi chiu trach nhiem xu ly
    resolved      BOOLEAN      NOT NULL DEFAULT false,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX ix_sync_error_batch ON sync_error (batch_id, resolved);

-- ---------------------------------------------------------------------
-- 7. api_log: nhat ky tung lan goi API cua Bo
--    KHONG ghi so CCCD, ho ten day du vao bang nay.
-- ---------------------------------------------------------------------
CREATE TABLE api_log (
    id            BIGSERIAL    PRIMARY KEY,
    batch_id      BIGINT       REFERENCES sync_batch (id) ON DELETE SET NULL,
    direction     VARCHAR(10)  NOT NULL DEFAULT 'OUT',
    method        VARCHAR(10)  NOT NULL,
    url           VARCHAR(1000) NOT NULL,
    http_status   INT,
    success       BOOLEAN,
    request_bytes BIGINT,
    duration_ms   BIGINT,
    response_body TEXT,                    -- cat ngan, da che du lieu ca nhan
    error         TEXT,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX ix_api_log_created ON api_log (created_at DESC);
CREATE INDEX ix_api_log_batch ON api_log (batch_id);

-- ---------------------------------------------------------------------
-- 8. sign_job: hang doi ky so cho tac nhan tren tram ky so
-- ---------------------------------------------------------------------
CREATE TABLE sign_job (
    id            BIGSERIAL    PRIMARY KEY,
    batch_id      BIGINT       NOT NULL REFERENCES sync_batch (id) ON DELETE CASCADE,
    status        VARCHAR(20)  NOT NULL,   -- PENDING | LEASED | SIGNED | FAILED
    xml_path      VARCHAR(500) NOT NULL,
    signed_path   VARCHAR(500),
    leased_by     VARCHAR(100),
    leased_at     TIMESTAMPTZ,
    attempts      INT          NOT NULL DEFAULT 0,
    error         TEXT,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX ix_sign_job_status ON sign_job (status, created_at);

-- ---------------------------------------------------------------------
-- 9. validation_rule: quy tac kiem tra sinh tu dac ta cua Bo
-- ---------------------------------------------------------------------
CREATE TABLE validation_rule (
    id            BIGSERIAL    PRIMARY KEY,
    ph            VARCHAR(50)  NOT NULL,
    entity        VARCHAR(100) NOT NULL,
    field         VARCHAR(100) NOT NULL,
    required      BOOLEAN      NOT NULL DEFAULT false,
    max_length    INT,
    data_type     VARCHAR(30),             -- string | int | double | date | bool | guid
    catalog_name  VARCHAR(100),            -- neu tham chieu danh muc HEMIS
    condition_expr VARCHAR(500),           -- vi du: bat buoc khi TRANG_THAI_ID = '04'
    note          VARCHAR(500),
    CONSTRAINT uq_validation_rule UNIQUE (ph, entity, field)
);
