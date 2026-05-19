-- Задание 1.3: Процедура расчёта формы 101

-- Идея: процедура принимает отчетную дату (первый день месяца, следующего за отчетным)
-- Например, для отчета за январь 2018 передаём '2018-02-01'
-- FROM_DATE = первый день отчетного периода (2018-01-01)
-- TO_DATE = последний день отчетного периода (2018-01-31)

CREATE OR REPLACE PROCEDURE DM.FILL_F101_ROUND_F(
    i_ReportDate DATE  -- первый день месяца, следующего за отчетным
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_from_date DATE;
    v_to_date DATE;
    v_prev_date DATE;
    v_rows_affected INTEGER;
    v_error_message TEXT;
BEGIN
    v_start_time := NOW();
    
    -- Вычисляем границы отчетного периода
    v_from_date := DATE_TRUNC('month', i_ReportDate - INTERVAL '1 month')::DATE;
    v_to_date := (DATE_TRUNC('month', i_ReportDate) - INTERVAL '1 day')::DATE;
    v_prev_date := v_from_date - 1;  -- день перед началом отчетного периода (31.12.2017 для января)
    
    -- Удаляем старые данные за этот период (для возможности перезапуска)
    DELETE FROM DM.DM_F101_ROUND_F 
    WHERE FROM_DATE = v_from_date AND TO_DATE = v_to_date;
    
    -- Основная вставка данных
    INSERT INTO DM.DM_F101_ROUND_F (
        FROM_DATE, TO_DATE, CHAPTER, LEDGER_ACCOUNT, CHARACTERISTIC,
        BALANCE_IN_RUB, BALANCE_IN_VAL, BALANCE_IN_TOTAL,
        TURN_DEB_RUB, TURN_DEB_VAL, TURN_DEB_TOTAL,
        TURN_CRE_RUB, TURN_CRE_VAL, TURN_CRE_TOTAL,
        BALANCE_OUT_RUB, BALANCE_OUT_VAL, BALANCE_OUT_TOTAL
    )
    SELECT 
        v_from_date,
        v_to_date,
        las.CHAPTER,
        LEFT(ac.ACCOUNT_NUMBER, 5) AS LEDGER_ACCOUNT,
        MAX(ac.CHAR_TYPE) AS CHARACTERISTIC,
        
        -- Входящие остатки (на день перед началом периода)
        SUM(CASE WHEN ac.CURRENCY_CODE IN ('810', '643') THEN COALESCE(balance_in.BALANCE_OUT_RUB, 0) ELSE 0 END) AS BALANCE_IN_RUB,
        SUM(CASE WHEN ac.CURRENCY_CODE NOT IN ('810', '643') THEN COALESCE(balance_in.BALANCE_OUT_RUB, 0) ELSE 0 END) AS BALANCE_IN_VAL,
        SUM(COALESCE(balance_in.BALANCE_OUT_RUB, 0)) AS BALANCE_IN_TOTAL,
        
        -- Дебетовые обороты за период
        SUM(CASE WHEN ac.CURRENCY_CODE IN ('810', '643') THEN COALESCE(turn.DEBET_AMOUNT_RUB, 0) ELSE 0 END) AS TURN_DEB_RUB,
        SUM(CASE WHEN ac.CURRENCY_CODE NOT IN ('810', '643') THEN COALESCE(turn.DEBET_AMOUNT_RUB, 0) ELSE 0 END) AS TURN_DEB_VAL,
        SUM(COALESCE(turn.DEBET_AMOUNT_RUB, 0)) AS TURN_DEB_TOTAL,
        
        -- Кредитовые обороты за период
        SUM(CASE WHEN ac.CURRENCY_CODE IN ('810', '643') THEN COALESCE(turn.CREDIT_AMOUNT_RUB, 0) ELSE 0 END) AS TURN_CRE_RUB,
        SUM(CASE WHEN ac.CURRENCY_CODE NOT IN ('810', '643') THEN COALESCE(turn.CREDIT_AMOUNT_RUB, 0) ELSE 0 END) AS TURN_CRE_VAL,
        SUM(COALESCE(turn.CREDIT_AMOUNT_RUB, 0)) AS TURN_CRE_TOTAL,
        
        -- Исходящие остатки (на последний день периода)
        SUM(CASE WHEN ac.CURRENCY_CODE IN ('810', '643') THEN COALESCE(balance_out.BALANCE_OUT_RUB, 0) ELSE 0 END) AS BALANCE_OUT_RUB,
        SUM(CASE WHEN ac.CURRENCY_CODE NOT IN ('810', '643') THEN COALESCE(balance_out.BALANCE_OUT_RUB, 0) ELSE 0 END) AS BALANCE_OUT_VAL,
        SUM(COALESCE(balance_out.BALANCE_OUT_RUB, 0)) AS BALANCE_OUT_TOTAL
        
    FROM DS.MD_ACCOUNT_D ac
        
    -- Соединяем со справочником балансовых счетов для получения главы
    LEFT JOIN DS.MD_LEDGER_ACCOUNT_S las 
        ON LEFT(ac.ACCOUNT_NUMBER, 5) = las.LEDGER_ACCOUNT::VARCHAR
        AND v_from_date BETWEEN las.START_DATE AND COALESCE(las.END_DATE, '9999-12-31')
        
    -- Входящие остатки (на день перед началом периода)
    LEFT JOIN DM.DM_ACCOUNT_BALANCE_F balance_in
        ON balance_in.ACCOUNT_RK = ac.ACCOUNT_RK
        AND balance_in.ON_DATE = v_prev_date
        
    -- Обороты за период
    LEFT JOIN (
        SELECT 
            ACCOUNT_RK,
            SUM(DEBET_AMOUNT_RUB) AS DEBET_AMOUNT_RUB,
            SUM(CREDIT_AMOUNT_RUB) AS CREDIT_AMOUNT_RUB
        FROM DM.DM_ACCOUNT_TURNOVER_F
        WHERE ON_DATE BETWEEN v_from_date AND v_to_date
        GROUP BY ACCOUNT_RK
    ) turn ON turn.ACCOUNT_RK = ac.ACCOUNT_RK
    
    -- Исходящие остатки (на последний день периода)
    LEFT JOIN DM.DM_ACCOUNT_BALANCE_F balance_out
        ON balance_out.ACCOUNT_RK = ac.ACCOUNT_RK
        AND balance_out.ON_DATE = v_to_date
        
    WHERE ac.DATA_ACTUAL_DATE <= v_to_date
      AND COALESCE(ac.DATA_ACTUAL_END_DATE, '9999-12-31') >= v_from_date
      
    GROUP BY 
        las.CHAPTER,
        LEFT(ac.ACCOUNT_NUMBER, 5)
    HAVING 
        SUM(COALESCE(balance_in.BALANCE_OUT_RUB, 0)) != 0
        OR SUM(COALESCE(turn.DEBET_AMOUNT_RUB, 0)) != 0
        OR SUM(COALESCE(turn.CREDIT_AMOUNT_RUB, 0)) != 0
        OR SUM(COALESCE(balance_out.BALANCE_OUT_RUB, 0)) != 0;
    
    -- Получаем количество затронутых записей
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    v_end_time := NOW();
    
    -- Логирование успешного выполнения
    INSERT INTO LOGS.ETL_LOG (TABLE_NAME, OPERATION_TYPE, START_TIME, END_TIME, ROWS_AFFECTED, STATUS)
    VALUES ('DM.DM_F101_ROUND_F', 'F101_LOAD', v_start_time, v_end_time, v_rows_affected, 'SUCCESS');
    
    RAISE NOTICE 'Форма 101 за период с % по %: добавлено % записей', v_from_date, v_to_date, v_rows_affected;
    
EXCEPTION WHEN OTHERS THEN
    v_end_time := NOW();
    v_error_message := SQLERRM;
    
    -- Логирование ошибки
    INSERT INTO LOGS.ETL_LOG (TABLE_NAME, OPERATION_TYPE, START_TIME, END_TIME, ROWS_AFFECTED, STATUS, ERROR_MESSAGE)
    VALUES ('DM.DM_F101_ROUND_F', 'F101_LOAD', v_start_time, v_end_time, 0, 'ERROR', v_error_message);
    
    RAISE NOTICE 'Ошибка: %', v_error_message;
    RAISE;
END;
$$;

-- Проверка создания процедуры
SELECT proname FROM pg_proc WHERE proname = 'fill_f101_round_f';