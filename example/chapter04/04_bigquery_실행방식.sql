-- =====================================================================
-- 실습 1. 일반 Query : 하나의 독립 Job, 상태 공유 없음
-- =====================================================================
-- [Query A] 독립 Job A 실행 → 종료
SELECT
    user_id,
    SUM(amount) AS total_amount
FROM `bq_course.orders`
WHERE status != 'CANCELED'
GROUP BY user_id
ORDER BY total_amount DESC;

-- [Query B] 새로운 Job B 실행
SELECT *
FROM `bq_course.orders`
WHERE amount >= min_amount;

-- 같은 변수를 쓰려면 매번 같은 Query 안에서 다시 선언해야 한다 → 실습 2(Script)로 연결


-- =====================================================================
-- 실습 2. Multi-statement Query (Script)
-- =====================================================================
-- Statement 1: 변수 선언
DECLARE min_amount NUMERIC DEFAULT 200000;

-- Statement 2: 임시 테이블 생성 (취소 주문 제외, 사용자별 집계)
CREATE TEMP TABLE temp_orders AS
SELECT
    user_id,
    COUNT(*)    AS order_count,
    SUM(amount) AS total_amount
FROM `bq_course.orders`
WHERE order_date >= '2026-09-01'
  AND status != 'CANCELED'
GROUP BY user_id;

-- Statement 3: 앞에서 만든 변수 + 임시 테이블을 함께 사용
--   예상 결과: 4명 (104, 103, 106, 102)
SELECT
    user_id,
    order_count,
    total_amount
FROM temp_orders
WHERE total_amount >= min_amount
ORDER BY total_amount DESC;

-- ---------------------------------------------------------------------
-- [확인] Script 가 끝난 뒤, 새로운 독립 Query 로 임시 테이블 조회
-- (위 Script 와 "별도로" 실행)
-- Script 종료 후에는 변수/임시 테이블 상태가 전달되지 않는다.
--   예상 에러: Not found: Table temp_orders ...
-- ---------------------------------------------------------------------
SELECT * FROM temp_orders;


-- =====================================================================
-- 실습 3. Session : 여러 Query Job 을 하나의 Session 으로 연결
-- =====================================================================

-- (1) ROLLBACK : 변경 후 되돌리기
BEGIN TRANSACTION;

UPDATE `bq_course.orders_tx_demo`
SET status = 'CANCELED'
WHERE order_id = 1001;

-- Result 1: 트랜잭션 안에서는 변경이 보인다 (아직 commit 전)
SELECT 'ROLLBACK 전' AS step, order_id, status
FROM `bq_course.orders_tx_demo`
WHERE order_id = 1001;            -- CANCELED

ROLLBACK TRANSACTION;

-- Result 2: 롤백 후 원래대로
SELECT 'ROLLBACK 후' AS step, order_id, status
FROM `bq_course.orders_tx_demo`
WHERE order_id = 1001;            -- PAID

-- (2) COMMIT : 변경 후 확정하기
BEGIN TRANSACTION;

UPDATE `bq_course.orders_tx_demo`
SET status = 'CANCELED'
WHERE order_id = 1001;

-- Result 3: 트랜잭션 안에서는 변경이 보인다 (아직 commit 전)
SELECT 'COMMIT 전' AS step, order_id, status
FROM `bq_course.orders_tx_demo`
WHERE order_id = 1001;            -- CANCELED

COMMIT TRANSACTION;

-- Result 4: 커밋 후에도 변경이 유지된다
SELECT 'COMMIT 후' AS step, order_id, status
FROM `bq_course.orders_tx_demo`
WHERE order_id = 1001;            -- CANCELED (영구 반영)

-- 다음 실습(②)을 위해 원래 상태로 복원 (트랜잭션 없이 일반 DML)
UPDATE `bq_course.orders_tx_demo`
SET status = 'PAID'
WHERE order_id = 1001;