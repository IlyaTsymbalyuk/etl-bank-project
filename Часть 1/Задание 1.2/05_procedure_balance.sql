-- Процедура расчёта витрины остатков DM.DM_ACCOUNT_BALANCE_F

CREATE OR REPLACE PROCEDURE DS.FILL_ACCOUNT_BALANCE_F(
    i_OnDate DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_prev_date DATE;
BEGIN
    v_prev_date := i_OnDate - 1;
    
    DELETE FROM DM.DM_ACCOUNT_BALANCE_F WHERE ON_DATE = i_OnDate;
    
    INSERT INTO DM.DM_ACCOUNT_BALANCE_F (ON_DATE, ACCOUNT_RK, BALANCE_OUT, BALANCE_OUT_RUB)
    SELECT 
        i_OnDate,
        ac.ACCOUNT_RK,
        ROUND((COALESCE(prev_bal.BALANCE_OUT, 0) 
            + CASE 
                WHEN ac.CHAR_TYPE = 'А' THEN COALESCE(turn.DEBET_AMOUNT, 0) - COALESCE(turn.CREDIT_AMOUNT, 0)
                WHEN ac.CHAR_TYPE = 'П' THEN COALESCE(prev_bal.BALANCE_OUT, 0) - COALESCE(turn.DEBET_AMOUNT, 0) + COALESCE(turn.CREDIT_AMOUNT, 0)
                ELSE 0
              END)::NUMERIC, 2),
        ROUND((COALESCE(prev_bal.BALANCE_OUT_RUB, 0)
            + CASE 
                WHEN ac.CHAR_TYPE = 'А' THEN COALESCE(turn.DEBET_AMOUNT_RUB, 0) - COALESCE(turn.CREDIT_AMOUNT_RUB, 0)
                WHEN ac.CHAR_TYPE = 'П' THEN COALESCE(prev_bal.BALANCE_OUT_RUB, 0) - COALESCE(turn.DEBET_AMOUNT_RUB, 0) + COALESCE(turn.CREDIT_AMOUNT_RUB, 0)
                ELSE 0
              END)::NUMERIC, 2)
    FROM DS.MD_ACCOUNT_D ac
    LEFT JOIN DM.DM_ACCOUNT_BALANCE_F prev_bal 
        ON prev_bal.ACCOUNT_RK = ac.ACCOUNT_RK 
        AND prev_bal.ON_DATE = v_prev_date
    LEFT JOIN DM.DM_ACCOUNT_TURNOVER_F turn 
        ON turn.ACCOUNT_RK = ac.ACCOUNT_RK 
        AND turn.ON_DATE = i_OnDate
    WHERE i_OnDate BETWEEN ac.DATA_ACTUAL_DATE AND COALESCE(ac.DATA_ACTUAL_END_DATE, '9999-12-31');
    
    INSERT INTO LOGS.ETL_LOG (TABLE_NAME, OPERATION_TYPE, START_TIME, END_TIME, ROWS_AFFECTED, STATUS)
    VALUES ('DM.DM_ACCOUNT_BALANCE_F', 'BALANCE_LOAD', NOW(), NOW(), 
            (SELECT COUNT(*) FROM DM.DM_ACCOUNT_BALANCE_F WHERE ON_DATE = i_OnDate), 
            'SUCCESS');
    
    RAISE NOTICE 'Остатки за %: % записей', i_OnDate, 
                 (SELECT COUNT(*) FROM DM.DM_ACCOUNT_BALANCE_F WHERE ON_DATE = i_OnDate);
END;
$$;