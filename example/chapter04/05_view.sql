


-- =====================================================================
-- A. Logical View : SELECT Query 정의만 저장하는 가상 Table (p44)
-- =====================================================================

-- A-1. View 생성
CREATE OR REPLACE VIEW `bq_course.v_orders_kr` AS
SELECT
    order_id,
    user_id,
    order_date,
    status,
    amount
FROM `bq_course.orders`
WHERE country = 'KR';

-- A-2. 일반 Table 처럼 조회 : country = 'KR' 조건을 매번 쓸 필요가 없다
--   예상 결과: 5건 (1001, 1002, 1004, 1007, 1010)
SELECT *
FROM `bq_course.v_orders_kr`
ORDER BY order_id;

-- 사용자 조건을 추가해도 Base Table Query 로 합쳐져 실행된다
SELECT *
FROM `bq_course.v_orders_kr`
WHERE amount >= 100000;           -- 1001, 1007


-- =====================================================================
-- B. Materialized View
-- =====================================================================

-- B-0. MV 의 Base Table : 파티션 테이블 (p46 : Base Table 이 Partitioned 여야 함)
CREATE OR REPLACE TABLE `bq_course.orders_partitioned`
PARTITION BY order_date
AS
SELECT *
FROM `bq_course.orders`;


-- ---------------------------------------------------------------------
-- B-1. [p45] 생성과 자동 Refresh
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW `bq_course.mv_orders_by_country`
OPTIONS (
    enable_refresh = true,
    refresh_interval_minutes = 60
)
AS
SELECT
    country,
    COUNT(*)    AS order_count,
    SUM(amount) AS total_amount
FROM `bq_course.orders_partitioned`
GROUP BY country;

-- MV 를 직접 조회 : 미리 계산된 결과를 읽는다
--   예상 결과: KR 5 / 444,000, JP 3 / 513,000, US 2 / 830,000
SELECT *
FROM `bq_course.mv_orders_by_country`
ORDER BY country;

-- [Smart Tuning] MV 이름을 쓰지 않고 Base Table 을 조회해도,
-- Optimizer 가 적합하다고 판단하면 MV 데이터를 활용한다.
-- (실행 후 Job information 에서 Materialized View 사용 여부 / 처리 바이트 확인)
SELECT
    country,
    SUM(amount) AS total_amount
FROM `bq_course.orders_partitioned`
GROUP BY country;



-- ---------------------------------------------------------------------
-- B-2. 데이터 갱신 : 조회 시점 기준으로 항상 최신 데이터를 반환한다
-- ---------------------------------------------------------------------
-- Base Table 에 신규 주문 추가 (MV 에는 아직 반영 전)
INSERT INTO `bq_course.orders_partitioned`
(order_id, user_id, order_date, created_at, status, country, amount, is_member)
VALUES
    (1011, 108, '2026-09-06', '2026-09-06 09:00:00+00', 'PAID', 'KR', 100000, TRUE);

-- 갱신 주기와 상관없이 "저장된 MV + 변경분(Delta)" 을 병합해서 반환
--   예상 결과: KR 6 / 544,000  (INSERT 직후인데도 반영되어 있다)
SELECT *
FROM `bq_course.mv_orders_by_country`
WHERE country = 'KR';

-- 수동 Refresh (필요할 때)
CALL BQ.REFRESH_MATERIALIZED_VIEW('bq_course.mv_orders_by_country');


-- ---------------------------------------------------------------------
-- B-4. [p48] max_staleness : 허용 가능한 데이터 지연 시간 설정
-- ---------------------------------------------------------------------
CREATE OR REPLACE MATERIALIZED VIEW `bq_course.mv_orders_stale_demo`
OPTIONS (
    enable_refresh = false,
    max_staleness = INTERVAL "0:2:0" HOUR TO SECOND      -- 2분까지 지연 허용 (실습용, 실무는 시간 단위)
)
AS
SELECT
    country,
    COUNT(*)    AS order_count,
    SUM(amount) AS total_amount
FROM `bq_course.orders_partitioned`
GROUP BY country;

-- 지금 시점으로 Refresh → "마지막 갱신 = 방금"
CALL BQ.REFRESH_MATERIALIZED_VIEW('bq_course.mv_orders_stale_demo');

-- Base Table 변경
INSERT INTO `bq_course.orders_partitioned`
(order_id, user_id, order_date, created_at, status, country, amount, is_member)
VALUES
    (1012, 109, '2026-09-06', '2026-09-06 10:00:00+00', 'PAID', 'KR', 50000, FALSE);

-- CASE 1 : 마지막 갱신이 허용 범위(2분) 안 → MV 에 저장된 결과만 조회
--   ※ CALL BQ.REFRESH 후 2분 이내에 실행한다.
--   예상 결과: KR 6 / 544,000  (1012 가 반영되지 않은 "허용된 지연" 데이터)
SELECT *
FROM `bq_course.mv_orders_stale_demo`
WHERE country = 'KR';

-- (2분 이상 기다린다. 슬라이드 p48 의 "마지막 갱신이 허용 범위 밖" 상황)

-- CASE 2 : 마지막 갱신으로부터 2분 초과 → 변경분을 병합해서 최신 결과 반환
--   같은 쿼리를 그대로 다시 실행한다.
--   예상 결과: KR 7 / 594,000  (Delta 병합으로 1012 까지 반영)
SELECT *
FROM `bq_course.mv_orders_stale_demo`
WHERE country = 'KR';



-- =====================================================================
-- C. Authorized View : Base Table 권한 없이 View 를 통해서만 데이터 제공
--
-- 시나리오
--   - 관리자(강사 계정) : bq_course.orders 에 모든 권한
--   - 실습용 사용자(다른 계정) : bq_course_view 데이터셋의 View 만 조회 가능
--   - View 는 user_id / is_member 를 숨기고, 한국(KR) 주문만 보여준다
--
-- ※ 실습용 사용자 계정이 하나 더 필요하다. (다른 Google 계정 / 브라우저 시크릿 창)
-- ※ Authorized View 의 View 는 "Base Table 과 다른 Dataset" 에 있어야 한다.
-- =====================================================================

-- C-1. [관리자] View 전용 Dataset 생성 (Base 와 같은 리전)
CREATE SCHEMA IF NOT EXISTS `bq_course_view`
    OPTIONS (
    location = 'asia-northeast2',
    description = 'Authorized View 실습용 데이터셋'
    );

-- C-2. [관리자] View 생성 : 컬럼(user_id, is_member 제외) + 행(KR) 제한
CREATE OR REPLACE VIEW `bq_course_view.v_orders_kr_public` AS
SELECT
    order_id,
    order_date,
    status,
    country,
    amount
FROM `bq_course.orders`
WHERE country = 'KR';

-- C-3. [관리자] 실습용 사용자에게 "View 데이터셋" 조회 권한만 부여
--   ※ 아래 이메일을 실습 계정으로 바꾼다.
--   ※ 해당 계정에는 프로젝트 레벨 roles/bigquery.jobUser (쿼리 실행 권한)도 필요하다.
--   ※ bq_course (Base 데이터셋) 에는 권한을 주지 않는다.
GRANT `roles/bigquery.dataViewer`
ON SCHEMA `bq_course_view`
TO "user:student@example.com";

-- ---------------------------------------------------------------------
-- C-4. [실습 사용자] 권한 부여 직후, 아직 Authorize 하기 전
-- ---------------------------------------------------------------------
-- (1) Base Table 직접 조회 → 권한 없음 (예상 에러: Access Denied ... User does not have permission)
SELECT * FROM `bq_course.orders`;

-- (2) 일반 View 상태에서는 View 를 조회해도 Base Table 권한이 필요하므로 에러
--     (Access Denied: Table bq_course.orders ...)
SELECT * FROM `bq_course_view.v_orders_kr_public`;

-- ---------------------------------------------------------------------
-- C-5. [관리자] View 를 Authorized View 로 등록 (콘솔)
--   BigQuery Studio → Explorer 에서 Base 데이터셋 `bq_course` 선택
--   → Sharing → Authorize Views → "Authorize view" 클릭
--   → `bq_course_view.v_orders_kr_public` 입력 → Add Authorization → Close
--
--   핵심 : 권한을 주는 대상은 "사용자" 가 아니라 "View",
--          등록하는 위치는 View 가 아니라 "Base Table 이 있는 Dataset" 이다.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- C-6. [실습 사용자] Authorize 이후 다시 조회
-- ---------------------------------------------------------------------
-- (1) View 조회 → 성공. 예상 결과 : KR 주문 5건, user_id / is_member 컬럼 없음
SELECT * FROM `bq_course_view.v_orders_kr_public` ORDER BY order_id;

-- (2) Base Table 직접 조회 → 여전히 Access Denied (사용자에게 직접 권한 없음)
SELECT * FROM `bq_course.orders`;

-- (3) View 에 정의되지 않은 컬럼 → 에러 (Unrecognized name: user_id)
SELECT user_id FROM `bq_course_view.v_orders_kr_public`;

