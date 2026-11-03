CREATE SCHEMA IF NOT EXISTS `thelook_ecommerce`
    OPTIONS (location = 'asia-northeast3');

CREATE SCHEMA IF NOT EXISTS `stackoverflow`
    OPTIONS (location = 'asia-northeast3');

-- TheLook eCommerce
CREATE OR REPLACE TABLE `thelook_ecommerce.orders` AS
SELECT * FROM `bigquery-public-data.thelook_ecommerce.orders`;

CREATE OR REPLACE TABLE `thelook_ecommerce.order_items` AS
SELECT * FROM `bigquery-public-data.thelook_ecommerce.order_items`;

CREATE OR REPLACE TABLE `thelook_ecommerce.users` AS
SELECT * FROM `bigquery-public-data.thelook_ecommerce.users`;

CREATE OR REPLACE TABLE `thelook_ecommerce.products` AS
SELECT * FROM `bigquery-public-data.thelook_ecommerce.products`;

CREATE OR REPLACE TABLE `thelook_ecommerce.events` AS
SELECT * FROM `bigquery-public-data.thelook_ecommerce.events`;

-- Stack Overflow
CREATE OR REPLACE TABLE `stackoverflow.posts_questions` AS
SELECT *
FROM `bigquery-public-data.stackoverflow.posts_questions`
WHERE creation_date >= '2018-01-01'
  AND creation_date < '2019-01-01';