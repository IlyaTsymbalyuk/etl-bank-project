-- Задание 2.2: Анализ пропущенных данных в витрине dm.loan_holiday_info
-- Цель: выявить, какие записи из источников отсутствуют в витрине

-- Шаг 1: Сравнение количества записей в витрине и источниках
-- Это поможет понять масштаб проблемы

SELECT 'Витрина dm.loan_holiday_info' as источник, COUNT(*) as количество_записей
FROM dm.loan_holiday_info

UNION ALL

SELECT 'Источник rd.deal_info (сделки)', COUNT(*) 
FROM rd.deal_info

UNION ALL

SELECT 'Источник rd.loan_holiday (кредитные каникулы)', COUNT(*)
FROM rd.loan_holiday

UNION ALL

SELECT 'Источник rd.product (продукты)', COUNT(*)
FROM rd.product;

-- Шаг 2: Находим сделки, которые отсутствуют в витрине
-- Сравниваем по составному ключу (deal_rk, effective_from_date)

SELECT 
    d.deal_rk as код_сделки,
    d.effective_from_date as дата_начала,
    d.effective_to_date as дата_окончания,
    d.deal_name as наименование_сделки,
    d.deal_sum as сумма_сделки,
    d.client_rk as код_клиента,
    d.product_rk as код_продукта
FROM rd.deal_info d
WHERE NOT EXISTS (
    SELECT 1 
    FROM dm.loan_holiday_info lhi
    WHERE lhi.deal_rk = d.deal_rk
      AND lhi.effective_from_date = d.effective_from_date
)
ORDER BY d.deal_rk, d.effective_from_date;

-- Шаг 3: Находим кредитные каникулы, отсутствующие в витрине

SELECT 
    lh.deal_rk as код_сделки,
    lh.effective_from_date as дата_начала,
    lh.effective_to_date as дата_окончания,
    lh.loan_holiday_start_date as дата_начала_каникул,
    lh.loan_holiday_finish_date as плановая_дата_окончания,
    lh.loan_holiday_type_cd as тип_каникул
FROM rd.loan_holiday lh
WHERE NOT EXISTS (
    SELECT 1 
    FROM dm.loan_holiday_info lhi
    WHERE lhi.deal_rk = lh.deal_rk
      AND lhi.effective_from_date = lh.effective_from_date
)
ORDER BY lh.deal_rk, lh.effective_from_date;

-- Шаг 4: Детальный анализ пропущенных периодов по датам
-- Объединяем данные из всех источников и сравниваем с витриной

WITH source_dates AS (
    -- Все даты из сделок
    SELECT 
        deal_rk,
        effective_from_date,
        effective_to_date,
        'сделка' as тип_источника
    FROM rd.deal_info
    
    UNION ALL
    
    -- Все даты из кредитных каникул
    SELECT 
        deal_rk,
        effective_from_date,
        effective_to_date,
        'кредитные_каникулы' as тип_источника
    FROM rd.loan_holiday
),
vitrine_dates AS (
    -- Все даты, которые есть в витрине
    SELECT DISTINCT
        deal_rk,
        effective_from_date,
        effective_to_date
    FROM dm.loan_holiday_info
)
SELECT 
    s.deal_rk as код_сделки,
    s.effective_from_date as дата_начала,
    s.effective_to_date as дата_окончания,
    s.тип_источника,
    CASE 
        WHEN v.deal_rk IS NULL THEN 'ОТСУТСТВУЕТ В ВИТРИНЕ'
        ELSE 'ПРИСУТСТВУЕТ'
    END as статус
FROM source_dates s
LEFT JOIN vitrine_dates v 
    ON v.deal_rk = s.deal_rk 
    AND v.effective_from_date = s.effective_from_date
WHERE v.deal_rk IS NULL
ORDER BY s.deal_rk, s.effective_from_date;