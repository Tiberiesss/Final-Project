    -- Создаем базу данных
CREATE DATABASE final_project;

	-- Создаем пустую таблицу customer_info
CREATE TABLE customer_info
	(
    Id_client int,
    Total_amount decimal,
    Gender varchar (10),
    Age int,
    Count_city int,
    Response_communcation tinyint,
    Communication_3month int,
    Tenure int
    );
    
    -- Принтим таблицу
    SELECT * FROM customer_info;
    
    -- Создаем таблицу transactions_info
    CREATE TABLE transactions_info
		(
        date_new date,
        Id_check int,
        ID_client int,
        Count_products float,
        Sum_payment float
        );
        
	-- Принтим таблицу
    SELECT * FROM transactions_info;

-- Задача №1
	-- Создаем временную таблицу с суммарной информацией по месяцам
WITH monthly_transactions AS (
    SELECT
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m') AS transaction_month,
        SUM(Sum_payment) AS total_payment_in_month,
        COUNT(*) AS transaction_count
    FROM transactions_info
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client, transaction_month
),
 
	-- Определяем клиентов с непрерывной историей за 12 месяцев
continuous_clients AS (
    SELECT
        ID_client
    FROM monthly_transactions
    GROUP BY ID_client
    HAVING COUNT(DISTINCT transaction_month) = 12
),

	-- Считаем агрегированные метрики по каждому клиенту
client_metrics AS (
    SELECT
        t.ID_client,
        COUNT(*) AS total_operations,
        ROUND(SUM(t.Sum_payment),2) AS total_sum_payment,
        AVG(t.Sum_payment) AS average_check
    FROM transactions_info t
    JOIN continuous_clients c ON t.ID_client = c.ID_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY t.ID_client
)

	-- Финальный запрос с результатами
SELECT
    c.ID_client,
    cm.total_operations,
    ROUND(cm.average_check, 2) AS average_check, -- Средний чек
    ROUND(cm.total_sum_payment / 12, 2) AS average_monthly_payment, -- Средняя сумма покупок за месяц
    cm.total_sum_payment AS total_payment -- Общая сумма покупок
FROM client_metrics cm
JOIN continuous_clients c ON cm.ID_client = c.ID_client
ORDER BY c.ID_client;

-- Задача №2
-- Вычисляем агрегированные метрики по месяцам
WITH monthly_metrics AS (
    SELECT
        DATE_FORMAT(t.date_new, '%Y-%m') AS transaction_month,
        COUNT(t.ID_check) AS total_operations,
        SUM(t.Sum_payment) AS total_sum_payment,
        COUNT(DISTINCT t.ID_client) AS unique_clients
    FROM transactions_info t
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY transaction_month
),

-- Получаем общее количество операций и сумму за весь год
annual_metrics AS (
    SELECT
        COUNT(ID_check) AS annual_operations,
        SUM(Sum_payment) AS annual_sum_payment
    FROM transactions_info
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
),

-- Половые метрики по месяцам с долей затрат
gender_metrics AS (
    SELECT
        DATE_FORMAT(t.date_new, '%Y-%m') AS transaction_month,
        c.Gender,
        COUNT(t.ID_check) AS operations_by_gender,
        SUM(t.Sum_payment) AS sum_payment_by_gender
    FROM transactions_info t
    JOIN customer_info c ON t.ID_client = c.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY transaction_month, c.Gender
)

-- Финальный запрос с объединением всех метрик
SELECT
    mm.transaction_month,
    -- Средняя сумма чека
    ROUND(mm.total_sum_payment / mm.total_operations, 2) AS average_check_per_month,
    -- Среднее количество операций
    mm.total_operations AS total_operations_in_month,
    -- Среднее количество клиентов
    mm.unique_clients AS unique_clients_in_month,
    -- Доли от общего количества операций и суммы за год
    ROUND(mm.total_operations / am.annual_operations * 100, 2) AS operation_share_percentage,
    ROUND(mm.total_sum_payment / am.annual_sum_payment * 100, 2) AS payment_share_percentage,
    -- % соотношение M/F/NA и их доля затрат
    gm.Gender,
    ROUND(gm.operations_by_gender / mm.total_operations * 100, 2) AS gender_operation_percentage,
    ROUND(gm.sum_payment_by_gender / mm.total_sum_payment * 100, 2) AS gender_payment_share
FROM monthly_metrics mm
CROSS JOIN annual_metrics am
LEFT JOIN gender_metrics gm ON mm.transaction_month = gm.transaction_month
ORDER BY mm.transaction_month, gm.Gender;

-- Задача №3
-- Создаем возрастные группы и считаем суммы и количество операций
WITH age_groups AS (
    SELECT
        CASE
            WHEN c.Age IS NULL THEN 'NA'
            WHEN c.Age BETWEEN 0 AND 9 THEN '0-9'
            WHEN c.Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN c.Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN c.Age BETWEEN 60 AND 69 THEN '60-69'
            ELSE '70+'
        END AS age_group,
        t.ID_client,
        t.Sum_payment,
        t.date_new
    FROM transactions_info t
    JOIN customer_info c ON t.ID_client = c.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
),

-- Агрегация данных по возрастным группам и кварталам
age_quarter_metrics AS (
    SELECT
        age_group,
        QUARTER(date_new) AS quarter,
        YEAR(date_new) AS year,
        COUNT(*) AS total_operations,
        ROUND(SUM(Sum_payment),2) AS total_sum_payment,
        AVG(Sum_payment) AS avg_payment
    FROM age_groups
    GROUP BY age_group, year, QUARTER(date_new)
),

-- Считаем общее количество операций и сумму за квартал для расчета долей
quarter_totals AS (
    SELECT
        QUARTER(date_new) AS quarter,
        YEAR(date_new) AS year,
        COUNT(*) AS total_operations_all,
        SUM(Sum_payment) AS total_sum_payment_all
    FROM age_groups
    GROUP BY year, QUARTER(date_new)
)

-- Финальный запрос с расчетами
SELECT
    aqm.year,
    aqm.quarter,
    aqm.age_group,
    aqm.total_operations,
    aqm.total_sum_payment,
    ROUND(aqm.avg_payment, 2) AS avg_payment_per_operation,
    ROUND(aqm.total_operations / qt.total_operations_all * 100, 2) AS operation_percentage,
    ROUND(aqm.total_sum_payment / qt.total_sum_payment_all * 100, 2) AS sum_percentage
FROM age_quarter_metrics aqm
JOIN quarter_totals qt 
    ON aqm.year = qt.year AND aqm.quarter = qt.quarter
ORDER BY aqm.year, aqm.quarter, aqm.age_group;
