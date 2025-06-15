-- ========================================
-- 1.発送数カレンダー作成
-- 商品 × 日付 の全組み合わせを作成
-- ========================================

CREATE OR REPLACE TABLE `sample.発送数カレンダー` AS
WITH calendar AS (
  SELECT date AS `日付`
  FROM UNNEST(GENERATE_DATE_ARRAY(DATE '2025-04-25', DATE '2025-05-31')) AS date
)
SELECT
  t1.`商品コード`,
  t1.`商品名`,
  t2.`日付`
FROM
  `sample.商品コードサンプル` t1
CROSS JOIN
  calendar t2
ORDER BY
  t2.`日付` ASC, t1.`商品コード` ASC;

-- ========================================
-- 2.貸出数集計
-- ========================================

-- ※ TEMP TABLEはセッション内限定で一時的に使われるテーブルです

CREATE TEMP TABLE `貸出数` AS
WITH AggregatedData AS (
  SELECT
    od.`商品コード`,
    A.`日付`,
    SUM(od.`数量`) AS `貸出数`
  FROM
    `sample.注文明細サンプル` AS od
  JOIN
    `sample.発送数カレンダー` AS A
  ON
    od.`商品コード` = A.`商品コード`
WHERE
    od.`発送日` <= A.`日付`
    AND od.`返却日` >= A.`日付`
  GROUP BY
    od.`商品コード`,
    A.`日付`
)
SELECT
  A.*,
  IFNULL(agg.`貸出数`, 0) AS `貸出数`
FROM
  `sample.発送数カレンダー` AS A
LEFT JOIN
  AggregatedData AS agg
ON
  A.`商品コード` = agg.`商品コード`
  AND A.`日付` = agg.`日付`
ORDER BY A.`日付`;

-- ========================================
-- 3.出荷数と返却予定数の計算
-- ========================================

CREATE TEMP TABLE `出荷数と返却予定数` AS
SELECT 
  A.`商品コード`, 
  A.`日付`, 
  COALESCE(SUM(B.`数量`), 0) AS `発送数`, 
  COALESCE(SUM(C.`数量`), 0) AS `返却予定数`
FROM `sample.発送数カレンダー` A
LEFT JOIN `sample.注文明細サンプル` B 
  ON A.`日付` = B.`発送日` 
  AND A.`商品コード` = B.`商品コード` 
LEFT JOIN `sample.注文明細サンプル` C 
  ON A.`日付` = C.`返却日` 
  AND A.`商品コード` = C.`商品コード` 
GROUP BY A.`日付`, A.`商品コード`
ORDER BY A.`日付`;

-- ========================================
-- 4.最終結合・出力
-- ========================================

CREATE OR REPLACE TABLE `sample.集計サンプル` AS
SELECT 
  D.*,
  E.`発送数`,
  E.`返却予定数`
FROM `貸出数` D
LEFT JOIN `出荷数と返却予定数` E
ON D.`商品コード` = E.`商品コード` AND D.`日付` = E.`日付`
ORDER BY
  D.`日付` ASC, D.`商品コード` ASC;
