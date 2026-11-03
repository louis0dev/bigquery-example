-- export를 이용한 bigquery to parquet
EXPORT DATA OPTIONS (
  uri = 'gs://YOUR_BUCKET/external/orders/orders-*.parquet',
  format = 'PARQUET',
  overwrite = TRUE
)
AS
SELECT
    *
FROM `thelook_ecommerce.orders`
WHERE created_at >= '2024-01-01'
LIMIT 10000;

-- 일반 external table 생성
CREATE OR REPLACE EXTERNAL TABLE
  `thelook_ecommerce.orders_external`
OPTIONS (
  format = 'PARQUET',
  uris = [
    'gs://YOUR_BUCKET/external/orders/*.parquet'
  ]
);

-- 데이터 조회
SELECT *
FROM `thelook_ecommerce.orders_external`
LIMIT 10;

SELECT
    status,
    COUNT(*) AS order_count
FROM `thelook_ecommerce.orders_external`
GROUP BY status
ORDER BY order_count DESC;