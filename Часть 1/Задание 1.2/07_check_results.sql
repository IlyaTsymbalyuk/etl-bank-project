-- Проверка результатов расчета витрин за январь 2018

-- 1. Проверка витрины оборотов: сколько записей по дням
SELECT 
    ON_DATE, 
    COUNT(*) as records_count,
    SUM(CREDIT_AMOUNT) as total_credit,
    SUM(DEBET_AMOUNT) as total_debet
FROM DM.DM_ACCOUNT_TURNOVER_F
WHERE ON_DATE BETWEEN '2018-01-01' AND '2018-01-31'
GROUP BY ON_DATE
ORDER BY ON_DATE;

-- 2. Проверка витрины остатков: сколько записей по дням
SELECT 
    ON_DATE, 
    COUNT(*) as records_count,
    SUM(BALANCE_OUT) as total_balance
FROM DM.DM_ACCOUNT_BALANCE_F
WHERE ON_DATE BETWEEN '2018-01-01' AND '2018-01-31'
GROUP BY ON_DATE
ORDER BY ON_DATE;

-- 3. Просмотр логов выполнения
SELECT 
    LOG_ID,
    TABLE_NAME,
    OPERATION_TYPE,
    START_TIME,
    END_TIME,
    ROWS_AFFECTED,
    STATUS,
    ERROR_MESSAGE
FROM LOGS.ETL_LOG 
WHERE OPERATION_TYPE IN ('TURNOVER_LOAD', 'BALANCE_LOAD', 'FULL_MONTH_LOAD')
ORDER BY LOG_ID DESC
LIMIT 20;

-- 4. Пример данных из витрины оборотов (первые 10 записей за 15 января)
SELECT * FROM DM.DM_ACCOUNT_TURNOVER_F 
WHERE ON_DATE = '2018-01-15' 
LIMIT 10;

-- 5. Пример данных из витрины остатков (первые 10 записей за 15 января)
SELECT * FROM DM.DM_ACCOUNT_BALANCE_F 
WHERE ON_DATE = '2018-01-15' 
LIMIT 10;


-- Проверка, какой код реально находится в процедуре оборотов
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'fill_account_turnover_f';

-- Очищаем
DELETE FROM DM.DM_ACCOUNT_TURNOVER_F WHERE ON_DATE = '2018-01-15';

-- Вызываем процедуру (она выведет сообщение в консоль)
CALL DS.FILL_ACCOUNT_TURNOVER_F('2018-01-15');

-- Вызываем процедуру остатков
CALL DS.FILL_ACCOUNT_BALANCE_F('2018-01-15');

SELECT 
    ON_DATE, 
    COUNT(*) as records_count
FROM DM.DM_ACCOUNT_TURNOVER_F
WHERE ON_DATE BETWEEN '2018-01-01' AND '2018-01-31'
GROUP BY ON_DATE
ORDER BY ON_DATE;

SELECT 
    ON_DATE, 
    COUNT(*) as records_count
FROM DM.DM_ACCOUNT_BALANCE_F
WHERE ON_DATE BETWEEN '2018-01-01' AND '2018-01-31'
GROUP BY ON_DATE
ORDER BY ON_DATE;