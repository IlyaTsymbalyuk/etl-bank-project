-- Задание 1.3: Полный перерасчёт формы 101
-- Этот файл удаляет все старые данные и заново запускает расчёт

-- 1. Удаляем все старые данные из витрины формы 101
TRUNCATE TABLE DM.DM_F101_ROUND_F;

-- 2. Запускаем расчёт за январь 2018 года
CALL DM.FILL_F101_ROUND_F('2018-02-01');

-- 3. Проверка: общее количество записей
SELECT 
    'Общее количество записей' as metric,
    COUNT(*) as value
FROM DM.DM_F101_ROUND_F;

-- 4. Проверка: первые 5 записей
SELECT * FROM DM.DM_F101_ROUND_F LIMIT 5;

-- 5. Проверка: итоговые суммы по периодам
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

-- 6. Просмотр логов выполнения
SELECT 
    LOG_ID,
    TABLE_NAME,
    OPERATION_TYPE,
    START_TIME,
    END_TIME,
    ROWS_AFFECTED,
    STATUS
FROM LOGS.ETL_LOG 
WHERE OPERATION_TYPE = 'F101_LOAD'
ORDER BY LOG_ID DESC
LIMIT 5;