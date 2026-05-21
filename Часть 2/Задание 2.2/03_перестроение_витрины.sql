-- Задание 2.2: Перестроение витрины dm.loan_holiday_info
-- Решение: полная перезагрузка (TRUNCATE + INSERT)
-- Почему полная перегрузка: объём данных невелик, нужно гарантировать целостность

-- Шаг 1: Очищаем витрину перед перезагрузкой
-- Удаляем все старые данные, чтобы избежать дублирования
TRUNCATE TABLE dm.loan_holiday_info;

-- Шаг 2: Перестраиваем витрину по исправленному прототипу

WITH deal AS (
    -- Получаем все данные о сделках из источника
    SELECT 
        deal_rk,
        deal_num,
        deal_name,
        deal_sum,
        client_rk,
        agreement_rk,
        deal_start_date,
        department_rk,
        product_rk,
        deal_type_cd,
        effective_from_date,
        effective_to_date
    FROM rd.deal_info
),
loan_holiday AS (
    -- Получаем все данные о кредитных каникулах
    SELECT 
        deal_rk,
        loan_holiday_type_cd,
        loan_holiday_start_date,
        loan_holiday_finish_date,
        loan_holiday_fact_finish_date,
        loan_holiday_finish_flg,
        loan_holiday_last_possible_date,
        effective_from_date,
        effective_to_date
    FROM rd.loan_holiday
),
product AS (
    -- Получаем справочник продуктов
    SELECT 
        product_rk,
        product_name,
        effective_from_date,
        effective_to_date
    FROM rd.product
),
holiday_info AS (
    -- Основной запрос: объединяем все три источника
    SELECT 
        d.deal_rk,
        -- Берём дату начала из сделки или из кредитных каникул (что есть)
        COALESCE(lh.effective_from_date, d.effective_from_date) as effective_from_date,
        -- Берём дату окончания из сделки или из кредитных каникул
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
    -- Левое соединение с кредитными каникулами (могут отсутствовать)
    LEFT JOIN loan_holiday lh 
        ON d.deal_rk = lh.deal_rk
        -- Условие: периоды действия должны пересекаться
        AND d.effective_from_date <= COALESCE(lh.effective_to_date, '9999-12-31')
        AND COALESCE(d.effective_to_date, '9999-12-31') >= lh.effective_from_date
    -- Левое соединение со справочником продуктов (может отсутствовать)
    LEFT JOIN product p 
        ON p.product_rk = d.product_rk
        -- Условие: периоды действия должны пересекаться
        AND d.effective_from_date <= COALESCE(p.effective_to_date, '9999-12-31')
        AND COALESCE(d.effective_to_date, '9999-12-31') >= p.effective_from_date
)
-- Вставляем результат в витрину
INSERT INTO dm.loan_holiday_info (
    deal_rk,
    effective_from_date,
    effective_to_date,
    agreement_rk,
    client_rk,
    department_rk,
    product_rk,
    product_name,
    deal_type_cd,
    deal_start_date,
    deal_name,
    deal_number,
    deal_sum,
    loan_holiday_type_cd,
    loan_holiday_start_date,
    loan_holiday_finish_date,
    loan_holiday_fact_finish_date,
    loan_holiday_finish_flg,
    loan_holiday_last_possible_date
)
SELECT 
    deal_rk,
    effective_from_date,
    effective_to_date,
    agreement_rk,
    client_rk,
    department_rk,
    product_rk,
    product_name,
    deal_type_cd,
    deal_start_date,
    deal_name,
    deal_number,
    deal_sum,
    loan_holiday_type_cd,
    loan_holiday_start_date,
    loan_holiday_finish_date,
    loan_holiday_fact_finish_date,
    loan_holiday_finish_flg,
    loan_holiday_last_possible_date
FROM holiday_info;

-- Шаг 3: Проверка результата
SELECT 'Количество записей в витрине после перестроения' as статус, COUNT(*) as количество
FROM dm.loan_holiday_info;