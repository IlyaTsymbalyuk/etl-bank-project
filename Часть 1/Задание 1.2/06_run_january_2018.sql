-- Запуск расчета витрин за каждый день января 2018 года

-- 1. Инициализация остатков на 31.12.2017
DELETE FROM DM.DM_ACCOUNT_BALANCE_F WHERE ON_DATE = '2017-12-31';

INSERT INTO DM.DM_ACCOUNT_BALANCE_F (ON_DATE, ACCOUNT_RK, BALANCE_OUT, BALANCE_OUT_RUB)
SELECT 
    ON_DATE,
    ACCOUNT_RK,
    BALANCE_OUT,
    BALANCE_OUT
FROM DS.FT_BALANCE_F 
WHERE ON_DATE = '2017-12-31';

-- 2. Очищаем старые данные за январь
DELETE FROM DM.DM_ACCOUNT_TURNOVER_F WHERE ON_DATE BETWEEN '2018-01-01' AND '2018-01-31';
DELETE FROM DM.DM_ACCOUNT_BALANCE_F WHERE ON_DATE BETWEEN '2018-01-01' AND '2018-01-31';

-- 3. Запускаем расчёт за весь январь
DO $$
DECLARE
    current_date DATE;
    start_date DATE := '2018-01-01';
    end_date DATE := '2018-01-31';
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_days_processed INTEGER := 0;
BEGIN
    v_start_time := NOW();
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Начало расчета витрин за январь 2018';
    RAISE NOTICE '========================================';
    
    FOR current_date IN SELECT generate_series(start_date, end_date, '1 day'::interval)::DATE
    LOOP
        CALL DS.FILL_ACCOUNT_TURNOVER_F(current_date);
        CALL DS.FILL_ACCOUNT_BALANCE_F(current_date);
        
        v_days_processed := v_days_processed + 1;
        RAISE NOTICE '✓ Обработан день: %', current_date;
    END LOOP;
    
    v_end_time := NOW();
    
    INSERT INTO LOGS.ETL_LOG (TABLE_NAME, OPERATION_TYPE, START_TIME, END_TIME, ROWS_AFFECTED, STATUS)
    VALUES ('DM_JAN_2018', 'FULL_MONTH_LOAD', v_start_time, v_end_time, v_days_processed, 'SUCCESS');
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Расчет завершен!';
    RAISE NOTICE '   Обработано дней: %', v_days_processed;
    RAISE NOTICE '   Время выполнения: %', v_end_time - v_start_time;
    RAISE NOTICE '========================================';
END;
$$;