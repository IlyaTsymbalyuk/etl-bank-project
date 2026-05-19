-- Задание 1.3: Проверка результатов формы 101

-- 1. Общее количество записей
SELECT COUNT(*) as total_records FROM DM.DM_F101_ROUND_F;

-- 2. Первые 20 записей
SELECT * FROM DM.DM_F101_ROUND_F LIMIT 20;

-- 3. Сводная статистика по форме 101
SELECT 
    FROM_DATE,
    TO_DATE,
    COUNT(*) as account_count,
    SUM(BALANCE_IN_TOTAL) as total_balance_in,
    SUM(TURN_DEB_TOTAL) as total_turn_deb,
    SUM(TURN_CRE_TOTAL) as total_turn_cre,
    SUM(BALANCE_OUT_TOTAL) as total_balance_out
FROM DM.DM_F101_ROUND_F
GROUP BY FROM_DATE, TO_DATE;

-- 4. Просмотр логов выполнения
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
WHERE OPERATION_TYPE = 'F101_LOAD'
ORDER BY LOG_ID DESC
LIMIT 5;