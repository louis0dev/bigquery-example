-- 파티셔닝만 적용
CREATE OR REPLACE TABLE `stackoverflow.questions_partitioned`
PARTITION BY DATE(creation_date)
AS
SELECT *
FROM `stackoverflow.posts_questions`;

-- 클러스터링만 적용
CREATE OR REPLACE TABLE `stackoverflow.questions_clustered`
CLUSTER BY owner_user_id
AS
SELECT *
FROM `stackoverflow.posts_questions`;

--파시셔닝/클러스터링 둘다 적용
CREATE OR REPLACE TABLE `stackoverflow.questions_optimized`
PARTITION BY DATE(creation_date)
CLUSTER BY owner_user_id
AS
SELECT *
FROM `stackoverflow.posts_questions`;

--테이블을 변경해가면서 효과를 확인

-- 실습 A. 날짜 조건만 사용, 파티셔닝 적용 효과 확인
SELECT
    id,
    title,
    body,
    creation_date,
    owner_user_id
FROM `stackoverflow.posts_questions`
WHERE creation_date >= '2018-01-01'
  AND creation_date < '2018-02-01';

-- 실습 B. 사용자 ID 조건만 사용, 클러스터링 효과 확인
SELECT
    owner_user_id,
    COUNT(*) AS question_count
FROM `stackoverflow.posts_questions`
WHERE owner_user_id IS NOT NULL
GROUP BY owner_user_id
HAVING COUNT(*) >= 10
ORDER BY question_count DESC
LIMIT 10;

SELECT
    id,
    title,
    body,
    creation_date,
    owner_user_id
FROM `stackoverflow.posts_questions`
WHERE owner_user_id = 12345;

-- 실습 C. 날짜 + 사용자 ID 조건 동시 사용, 파티션과 클러스터링 효과 확인
SELECT
    owner_user_id,
    COUNT(*) AS question_count
FROM `stackoverflow.posts_questions`
WHERE creation_date >= '2018-01-01'
  AND creation_date < '2018-02-01'
  AND owner_user_id IS NOT NULL
GROUP BY owner_user_id
ORDER BY question_count DESC
    LIMIT 10;

SELECT
    id,
    title,
    body,
    creation_date,
    owner_user_id
FROM `stackoverflow.posts_questions`
WHERE creation_date >= '2018-01-01'
  AND creation_date < '2018-02-01'
  AND owner_user_id = 12345;