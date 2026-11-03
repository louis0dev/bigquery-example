-- =====================================================================
-- Routine 실습 (슬라이드 51~55)
--   A. Stored Procedure                       (p51, p52)
--   B. User-Defined Function (UDF)            (p53, p54)
--      - SQL UDF / JavaScript UDF / Python UDF, Temporary vs Persistent
--   C. Table-Valued Function (TVF)            (p55)
-- 사용 데이터셋: bq_course (asia-northeast2)
-- 전제: 앞선 실습에서 만든 테이블 / View / MV 는 삭제하지 않고 그대로 둔다.
--       (이 파일의 객체도 정리하지 않으며, 모든 CREATE 는 재실행 가능하게 OR REPLACE 사용)
--   ※ 슬라이드는 public data(usa_names)를 쓰는 예제가 있으나, 리전이 달라
--     bq_course.orders 기반으로 같은 개념을 실습한다.
-- =====================================================================


-- =====================================================================
-- 사전 준비 : 실습용 테이블
-- =====================================================================

-- p52 Stored Procedure 용 : 고객 테이블
CREATE OR REPLACE TABLE `bq_course.customers` (
    customer_id STRING,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- p51 Stored Procedure(DML) 용 : orders 복사본 (원본 보호)
CREATE OR REPLACE TABLE `bq_course.orders_routine_demo` AS
SELECT * FROM `bq_course.orders`;

-- p53 UDF 용 : fruits
CREATE OR REPLACE TABLE `bq_course.fruits` AS
SELECT fruit
FROM UNNEST(['apple', 'banana', 'cherry']) AS fruit;

-- p54 UDF 용 : persons (age 는 SQL UDF, payload 는 JavaScript UDF 용)
CREATE OR REPLACE TABLE `bq_course.persons` AS
SELECT * FROM UNNEST([
    STRUCT('Alice' AS name, 30 AS age, '{"name":"Alice","age":30}' AS payload),
        STRUCT('Bob',           25,        '{"name":"Bob","age":25}'),
        STRUCT('Cathy',         41,        '{"name":"Cathy","age":41}')
            ]);

-- p55 TVF JOIN 용 : 국가 메타데이터
CREATE OR REPLACE TABLE `bq_course.country_metadata` AS
SELECT * FROM UNNEST([
    STRUCT('KR' AS country, 'Korea' AS country_name),
        STRUCT('JP', 'Japan'),
        STRUCT('US', 'United States')
            ]);


-- =====================================================================
-- A. Stored Procedure : 여러 SQL 문 + 제어 흐름을 하나의 절차로, CALL 로 실행
-- =====================================================================

-- ---------------------------------------------------------------------
-- A-1. [p52] Parameter + DECLARE + IF/ELSE + DML (INSERT)
--   입력 ID 가 NULL 이면 GENERATE_UUID() 로 생성, 아니면 입력값 사용
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE `bq_course.create_customer_with_check`(IN input_id STRING)
BEGIN
    DECLARE id STRING;

    -- 입력된 ID가 NULL인지 확인
    IF input_id IS NULL THEN
        SET id = GENERATE_UUID();
        SELECT FORMAT("ID가 입력되지 않아 자동 생성했습니다: %s", id);
    ELSE
        SET id = input_id;
        SELECT FORMAT("입력된 ID를 사용합니다: %s", id);
    END IF;

INSERT INTO `bq_course.customers` (customer_id)
VALUES (id);
END;

-- CASE 1 : ID 를 전달하지 않음 → NULL → 새 customer_id 생성 → INSERT
CALL `bq_course.create_customer_with_check`(NULL);

-- CASE 2 : ID 를 직접 전달 → 입력값 그대로 사용 → INSERT
CALL `bq_course.create_customer_with_check`('custom-id-123');

-- 확인 : 2건 (UUID 1건 + custom-id-123)
SELECT customer_id, created_at
FROM `bq_course.customers`
ORDER BY created_at;

-- =====================================================================
-- B. User-Defined Function (UDF) : 입력 값 → 단일 값 반환
-- =====================================================================

-- ---------------------------------------------------------------------
-- B-1. [p53] 각 Row 마다 UDF 가 실행된다 (N개의 Row → UDF N번 → N개의 Scalar Value)
-- ---------------------------------------------------------------------

-- Persistent UDF : Dataset 에 저장, 여러 Query 에서 재사용
CREATE OR REPLACE FUNCTION `bq_course.custom_udf`(fruit STRING)
RETURNS STRING
AS (
    UPPER(fruit)
);

-- Query 안에서 호출 : apple → APPLE, banana → BANANA, cherry → CHERRY
SELECT
    fruit,
    `bq_course.custom_udf`(fruit) AS result
FROM `bq_course.fruits`;

-- 다른 Query 에서도 그대로 재사용 가능 (Query A, B, C 에서 같은 함수 사용)
SELECT `bq_course.custom_udf`('hello bigquery') AS result;


-- ---------------------------------------------------------------------
-- B-2. [p53] Temporary UDF : 현재 Query / Script 범위에서만 존재
--   (1) 아래 Script 를 한 번에 실행 → 성공
-- ---------------------------------------------------------------------
CREATE TEMP FUNCTION temp_udf(fruit STRING) RETURNS STRING AS (
    CONCAT('[', UPPER(fruit), ']')
);

SELECT fruit, temp_udf(fruit) AS result
FROM `bq_course.fruits`;

--   (2) 별도 Query 로 다시 실행 → Query 종료와 함께 UDF 소멸 → 에러가 정상
--       예상 에러: Function not found: temp_udf
SELECT temp_udf('apple');



-- ---------------------------------------------------------------------
-- B-3. JavaScript UDF : SQL 로 표현하기 어려운 로직 (문자열 / JSON 처리)
--   JSON 문자열에서 특정 필드 추출  → "Alice"
--   ※ 가능하면 SQL UDF 를 우선 사용한다.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION `bq_course.get_field`(json_input STRING, target_field STRING)
RETURNS STRING
LANGUAGE js
AS r"""
    var row = JSON.parse(json_input);
    if (row && typeof row === 'object') {
        var val = row[target_field];
        if (val != null) return String(val);
    }
    return null;
""";

-- name : Alice / Bob / Cathy,  age : 30 / 25 / 41 (문자열로 반환)
SELECT
    `bq_course.get_field`(payload, 'name') AS name_field,
    `bq_course.get_field`(payload, 'age')  AS age_field
FROM `bq_course.persons`
ORDER BY name_field;


-- ---------------------------------------------------------------------
-- B-4. [p54] Python UDF : Python 코드 / 라이브러리 사용 (Persistent only)
--   ※ Python UDF 는 사용 가능한 프로젝트 / 리전인지 사전 확인이 필요하다.
--   ※ 슬라이드와 같은 형태 : entry_point, runtime_version 지정
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION `bq_course.multiply_inputs`(x INT64, y INT64)
RETURNS INT64
LANGUAGE python
OPTIONS (
    entry_point = 'multiply_inputs',
    runtime_version = 'python-3.11'
)
AS r"""
def multiply_inputs(x, y):
    return x * y
""";

SELECT `bq_course.multiply_inputs`(10, 3) AS result;          -- 30



-- =====================================================================
-- C. Table-Valued Function (TVF) : Parameter 를 받아 Table 을 반환 (p55)
--   View 는 "고정된 Query → Table",  TVF 는 "Parameter → Query → Table"
--   ※ 슬라이드의 names_by_year_and_prefix(year, prefix) 를
--     orders 의 (country, min_amount) 로 바꾼 예제
-- =====================================================================

-- C-1. TVF 생성
CREATE OR REPLACE TABLE FUNCTION `bq_course.orders_by_country_and_amount`(
    c          STRING,       -- 국가 Parameter
    min_amount NUMERIC       -- 최소 금액 Parameter
)
AS (
    SELECT
        order_id,
        user_id,
        order_date,
        country,
        status,
        amount
    FROM `bq_course.orders`
    WHERE country = c
      AND amount >= min_amount
);

-- C-2. TVF 실행 : FROM 절에서 Table 처럼 사용
--   예상 결과: 1001 (150,000), 1007 (125,000)
SELECT *
FROM `bq_course.orders_by_country_and_amount`('KR', 100000)
ORDER BY amount DESC
    LIMIT 5;

-- 같은 함수, 다른 Parameter : JP 전체 (min_amount = 0) → 1003, 1009, 1006
SELECT *
FROM `bq_course.orders_by_country_and_amount`('JP', 0)
ORDER BY amount DESC;

-- C-3. JOIN 에서도 Table 처럼 사용
--   예상 결과: 1003 / Japan, 1009 / Japan 포함 3건
SELECT
    o.order_id,
    o.amount,
    m.country_name
FROM `bq_course.orders_by_country_and_amount`('JP', 0) AS o
         JOIN `bq_course.country_metadata` AS m
              ON o.country = m.country
ORDER BY o.order_id;
