-- Задание 2.3: Создание процедуры для автоматического обновления витрины
-- Процедура сначала исправляет данные в rd.account_balance, затем перестраивает витрину

CREATE OR REPLACE PROCEDURE dm.обновить_витрину_оборотов()
LANGUAGE plpgsql
AS $$
DECLARE
    время_начала TIMESTAMP;
    время_окончания TIMESTAMP;
    количество_записей INTEGER;
    исправлено_in INTEGER;
    исправлено_out INTEGER;
    текст_ошибки TEXT;
BEGIN
    время_начала := NOW();
    
    RAISE NOTICE 'Начало обновления витрины dm.account_balance_turnover';
    
    -- Часть 1: Исправление данных в rd.account_balance
    -- Исправляем account_in_sum на основе account_out_sum предыдущего дня
    RAISE NOTICE 'Шаг 1: Исправление account_in_sum';
    
    WITH balance_with_prev AS (
        SELECT 
            ctid as row_id,
            account_rk,
            effective_date,
            account_in_sum,
            LAG(account_out_sum) OVER (PARTITION BY account_rk ORDER BY effective_date) as correct_account_in_sum
        FROM rd.account_balance
    )
    UPDATE rd.account_balance
    SET account_in_sum = bwp.correct_account_in_sum
    FROM balance_with_prev bwp
    WHERE rd.account_balance.ctid = bwp.row_id
      AND bwp.correct_account_in_sum IS NOT NULL
      AND rd.account_balance.account_in_sum != bwp.correct_account_in_sum;
    
    GET DIAGNOSTICS исправлено_in = ROW_COUNT;
    RAISE NOTICE 'Исправлено account_in_sum: % записей', исправлено_in;
    
    -- Исправляем account_out_sum на основе account_in_sum следующего дня
    RAISE NOTICE 'Шаг 2: Исправление account_out_sum';
    
    WITH balance_with_next AS (
        SELECT 
            ctid as row_id,
            account_rk,
            effective_date,
            account_out_sum,
            LEAD(account_in_sum) OVER (PARTITION BY account_rk ORDER BY effective_date) as correct_account_out_sum
        FROM rd.account_balance
    )
    UPDATE rd.account_balance
    SET account_out_sum = bwn.correct_account_out_sum
    FROM balance_with_next bwn
    WHERE rd.account_balance.ctid = bwn.row_id
      AND bwn.correct_account_out_sum IS NOT NULL
      AND rd.account_balance.account_out_sum != bwn.correct_account_out_sum;
    
    GET DIAGNOSTICS исправлено_out = ROW_COUNT;
    RAISE NOTICE 'Исправлено account_out_sum: % записей', исправлено_out;
    
    -- Часть 2: Перестроение витрины
    RAISE NOTICE 'Шаг 3: Перестроение витрины dm.account_balance_turnover';
    
    -- Очищаем витрину
    TRUNCATE TABLE dm.account_balance_turnover;
    
    -- Заполняем витрину заново
    INSERT INTO dm.account_balance_turnover (
        account_rk,
        currency_name,
        department_rk,
        effective_date,
        account_in_sum,
        account_out_sum
    )
    SELECT 
        a.account_rk,
        COALESCE(dc.currency_name, '-1') as currency_name,
        a.department_rk,
        ab.effective_date,
        ab.account_in_sum,
        ab.account_out_sum
    FROM rd.account a
    LEFT JOIN rd.account_balance ab ON a.account_rk = ab.account_rk
    LEFT JOIN dm.dict_currency dc ON a.currency_cd = dc.currency_cd
    ORDER BY a.account_rk, ab.effective_date;
    
    GET DIAGNOSTICS количество_записей = ROW_COUNT;
    время_окончания := NOW();
    
    -- Логирование успешного выполнения
    INSERT INTO LOGS.ETL_LOG (TABLE_NAME, OPERATION_TYPE, START_TIME, END_TIME, ROWS_AFFECTED, STATUS)
    VALUES ('dm.account_balance_turnover', 'ОБНОВЛЕНИЕ_ВИТРИНЫ', время_начала, время_окончания, количество_записей, 'УСПЕХ');
    
    -- Выводим итоговые сообщения
    RAISE NOTICE 'Обновление витрины завершено успешно';
    RAISE NOTICE 'Исправлено account_in_sum: %', исправлено_in;
    RAISE NOTICE 'Исправлено account_out_sum: %', исправлено_out;
    RAISE NOTICE 'Загружено записей в витрину: %', количество_записей;
    RAISE NOTICE 'Время выполнения: %', время_окончания - время_начала;
    
EXCEPTION WHEN OTHERS THEN
    -- Если произошла ошибка
    время_окончания := NOW();
    текст_ошибки := SQLERRM;
    
    INSERT INTO LOGS.ETL_LOG (TABLE_NAME, OPERATION_TYPE, START_TIME, END_TIME, ROWS_AFFECTED, STATUS, ERROR_MESSAGE)
    VALUES ('dm.account_balance_turnover', 'ОБНОВЛЕНИЕ_ВИТРИНЫ', время_начала, время_окончания, 0, 'ОШИБКА', текст_ошибки);
    
    RAISE NOTICE 'Ошибка при обновлении: %', текст_ошибки;
    RAISE;
END;
$$;

-- Запуск процедуры
CALL dm.обновить_витрину_оборотов();

-- Проверка результата
SELECT COUNT(*) as количество_записей_в_витрине FROM dm.account_balance_turnover;