-- 커넥션 생성
-- Connections → Create connection,
-- Connection ID: biglake-demo
-- Location: asia-northeast3
CREATE CONNECTION IF NOT EXISTS
  `asia-northeast3.biglake-demo`
OPTIONS (
  connection_type = 'CLOUD_RESOURCE',
  friendly_name = 'BigLake Demo Connection'
);

-- 서비스 어카운트 권한 부여
-- roles/storage.objectViewer
-- roles/storage.objectUser
-- roles/storage.legacyBucketReader

-- iceberg 테이블 생성
CREATE TABLE `thelook_ecommerce.orders_iceberg` (
    order_id INT64,
    user_id INT64,
    status STRING,
    created_at TIMESTAMP,
    returned_at TIMESTAMP,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    num_of_item INT64
)
WITH CONNECTION `asia-northeast3.biglake-demo`
OPTIONS (
    file_format = 'PARQUET',
    table_format = 'ICEBERG',
    storage_uri = 'gs://YOUR_BUCKET/iceberg/orders'
);

-- 데이터 insert
INSERT INTO `thelook_ecommerce.orders_iceberg`
SELECT
    order_id,
    user_id,
    status,
    created_at,
    returned_at,
    shipped_at,
    delivered_at,
    num_of_item
FROM `thelook_ecommerce.orders`
WHERE created_at >= '2024-01-01'
    LIMIT 10000;

-- 새로운 주문 입력
INSERT INTO `thelook_ecommerce.orders_iceberg`
(order_id, user_id, status, created_at, num_of_item)
VALUES
    (999999, 101, 'Processing', CURRENT_TIMESTAMP(), 2);

-- 주문 상태 변경
UPDATE `thelook_ecommerce.orders_iceberg`
SET status = 'Shipped'
WHERE order_id = 999999;

-- 변경 결과 확인
SELECT *
FROM `thelook_ecommerce.orders_iceberg`
WHERE order_id = 999999;