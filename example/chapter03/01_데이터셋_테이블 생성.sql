-- dataset 생성
CREATE SCHEMA IF NOT EXISTS `bq_course`
    OPTIONS (
    location = 'asia-northeast2',
    description = 'BigQuery 강의 실습용 데이터셋'
);

-- 테이블 생성
CREATE OR REPLACE TABLE `bq_course.orders` (
  order_id INT64 NOT NULL OPTIONS(description='주문 ID'),
  user_id INT64 NOT NULL OPTIONS(description='사용자 ID'),
  order_date DATE OPTIONS(description='주문 날짜'),
  created_at TIMESTAMP OPTIONS(description='주문 생성 시각'),
  status STRING OPTIONS(description='주문 상태'),
  country STRING OPTIONS(description='주문 국가'),
  amount NUMERIC OPTIONS(description='주문 금액'),
  is_member BOOL OPTIONS(description='회원 여부')
)
OPTIONS (
  description = 'BigQuery 강의용 주문 테이블'
);

-- insert query
INSERT INTO `bq_course.orders`
(order_id, user_id, order_date, created_at, status, country, amount, is_member)
VALUES
    (1001, 101, '2026-09-01', '2026-09-01 10:15:00+00',
     'PAID', 'KR', 150000, TRUE),

    (1002, 102, '2026-09-01', '2026-09-01 11:20:00+00',
     'SHIPPED', 'KR', 89000, FALSE),

    (1003, 103, '2026-09-02', '2026-09-02 09:30:00+00',
     'PAID', 'JP', 240000, TRUE),

    (1004, 101, '2026-09-02', '2026-09-02 14:45:00+00',
     'CANCELED', 'KR', 35000, TRUE),

    (1005, 104, '2026-09-03', '2026-09-03 08:10:00+00',
     'COMPLETED', 'US', 520000, FALSE),

    (1006, 105, '2026-09-03', '2026-09-03 16:25:00+00',
     'PAID', 'JP', 78000, TRUE),

    (1007, 102, '2026-09-04', '2026-09-04 13:00:00+00',
     'SHIPPED', 'KR', 125000, FALSE),

    (1008, 106, '2026-09-04', '2026-09-04 18:40:00+00',
     'COMPLETED', 'US', 310000, TRUE),

    (1009, 103, '2026-09-05', '2026-09-05 10:05:00+00',
     'PAID', 'JP', 195000, TRUE),

    (1010, 107, '2026-09-05', '2026-09-05 21:15:00+00',
     'CANCELED', 'KR', 45000, FALSE);

-- 조회 쿼리
-- 전체 조회
SELECT *
FROM `bq_course.orders`
ORDER BY order_id;

-- 조건 조회
SELECT order_id, user_id, amount
FROM `bq_course.orders`
WHERE country = 'KR';

-- 주문 상태별 집계
SELECT
    status,
    COUNT(*) AS order_count,
    SUM(amount) AS total_amount
FROM `bq_course.orders`
GROUP BY status;