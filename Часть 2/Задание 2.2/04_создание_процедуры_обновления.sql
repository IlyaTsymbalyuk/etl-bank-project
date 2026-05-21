-- Задание 2.2: Создание процедуры для автоматического обновления витрины
-- Это позволит перезапускать обновление витрины в любой момент

CREATE OR REPLACE PROCEDURE dm.обновить_витрину_кредитных_каникул()
LANGUAGE plpgsql
AS $$
DECLARE
    время_начала TIMESTAMP;
    время_окончания TIMESTAMP;
    количество_записей INTEGER;
    текст_ошибки TEXT;
BEGIN
    -- Запоминаем время начала выполнения
    время_начала := NOW();
    
    -- Выводим сообщение в консоль для отслеживания прогресса
    RAISE NOTICE 'Начало обновления витрины dm.loan_holiday_info';
    
    -- Очищаем витрину перед загрузкой (полная перезагрузка)
    TRUNCATE TABLE dm.loan_holiday_info;
    RAISE NOTICE 'Старые данные удалены';
    
    -- Перестраиваем витрину (аналогично файлу 03_перестроение_витрины.sql)
    WITH deal AS (
        SELECT 
            deal_rk, deal_num, deal_name, deal_sum, client_rk,
            agreement_rk, deal_start_date, department_rk, product_rk,
            deal_type_cd, effective_from_date, effective_to_date
        FROM rd.deal_info
    ),
    loan_holiday AS (
        SELECT 
            deal_rk, loan_holiday_type_cd, loan_holiday_start_date,
            loan_holiday_finish_date, loan_holiday_fact_finish_date,
            loan_holiday_finish_flg, loan_holiday_last_possible_date,
            effective_from_date, effective_to_date
        FROM rd.loan_holiday
    ),
    product AS (
        SELECT product_rk, product_name, effective_from_date, effective_to_date
        FROM rd.product
    ),
    holiday_info AS (
        SELECT 
            d.deal_rk,
            COALESCE(lh.effective_from_date, d.effective_from_date) as effective_from_date,
            COALESCE(lh.effective_to_date, d.effective_to_date) as effective_to_date,
            d.deal_num as deal_number,
            lh.loan_holiday_type_cd,
            lh.loan_holiday_start_date,
            lh.loan_holiday_finish_date,
            lh.loan_holiday_fact_finish_date,
            lh.loan_holiday_finish_flg,
            lh.loan_holiday_last_possible_date,
            d.deal_name,
            d.deal_sum,
            d.client_rk,
            d.agreement_rk,
            d.deal_start_date,
            d.department_rk,
            d.product_rk,
            p.product_name,
            d.deal_type_cd
        FROM deal d
        LEFT JOIN loan_holiday lh 
            ON d.deal_rk = lh.deal_rk
            AND d.effective_from_date <= COALESCE(lh.effective_to_date, '9999-12-31')
            AND COALESCE(d.effective_to_date, '9999-12-31') >= lh.effective_from_date
        LEFT JOIN product p 
            ON p.product_rk = d.product_rk
            AND d.effective_from_date <= COALESCE(p.effective_to_date, '9999-12-31')
            AND COALESCE(d.effective_to_date, '9999-12-31') >= p.effective_from_date
    )
    INSERT INTO dm.loan_holiday_info (
        deal_rk, effective_from_date, effective_to_date, agreement_rk, client_rk,
        department_rk, product_rk, product_name, deal_type_cd, deal_start_date,
        deal_name, deal_number, deal_sum, loan_holiday_type_cd,
        loan_holiday_start_date, loan_holiday_finish_date,
        loan_holiday_fact_finish_date, loan_holiday_finish_flg,
        loan_holiday_last_possible_date
    )
    SELECT 
        deal_rk, effective_from_date, effective_to_date, agreement_rk, client_rk,
        department_rk, product_rk, product_name, deal_type_cd, deal_start_date,
        deal_name, deal_number, deal_sum, loan_holiday_type_cd,
        loan_holiday_start_date, loan_holiday_finish_date,
        loan_holiday_fact_finish_date, loan_holiday_finish_flg,
        loan_holiday_last_possible_date
    FROM holiday_info;
    
    -- Получаем количество добавленных записей
    GET DIAGNOSTICS количество_записей = ROW_COUNT;
    время_окончания := NOW();
    
    -- Записываем в лог успешное выполнение
    INSERT INTO LOGS.ETL_LOG (TABLE_NAME, OPERATION_TYPE, START_TIME, END_TIME, ROWS_AFFECTED, STATUS)
    VALUES ('dm.loan_holiday_info', 'ОБНОВЛЕНИЕ', время_начала, время_окончания, количество_записей, 'УСПЕХ');
    
    -- Выводим итоговые сообщения в консоль
    RAISE NOTICE 'Обновление завершено успешно';
    RAISE NOTICE 'Добавлено записей: %', количество_записей;
    RAISE NOTICE 'Время выполнения: %', время_окончания - время_начала;
    
EXCEPTION WHEN OTHERS THEN
    -- Если произошла ошибка, записываем её в лог
    время_окончания := NOW();
    текст_ошибки := SQLERRM;
    
    INSERT INTO LOGS.ETL_LOG (TABLE_NAME, OPERATION_TYPE, START_TIME, END_TIME, ROWS_AFFECTED, STATUS, ERROR_MESSAGE)
    VALUES ('dm.loan_holiday_info', 'ОБНОВЛЕНИЕ', время_начала, время_окончания, 0, 'ОШИБКА', текст_ошибки);
    
    -- Выводим ошибку в консоль
    RAISE NOTICE 'Ошибка при обновлении: %', текст_ошибки;
    RAISE;
END;
$$;

-- Запуск процедуры для обновления витрины
CALL dm.обновить_витрину_кредитных_каникул();

-- Проверка результата после вызова процедуры
SELECT 'Количество записей после обновления' as статус, COUNT(*) as количество
FROM dm.loan_holiday_info;