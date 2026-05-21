-- Задание 2.2: Проверка результатов после обновления витрины

-- 1. Количество записей в витрине после обновления
SELECT 'После обновления' as статус, COUNT(*) as количество_записей
FROM dm.loan_holiday_info;

-- 2. Проверка: все ли сделки из источника теперь в витрине?
-- Должно вернуться 0 (ноль пропущенных сделок)
SELECT 
    COUNT(*) as количество_пропущенных_сделок
FROM rd.deal_info d
WHERE NOT EXISTS (
    SELECT 1 FROM dm.loan_holiday_info lhi
    WHERE lhi.deal_rk = d.deal_rk
      AND lhi.effective_from_date = d.effective_from_date
);

-- 3. Проверка: все ли кредитные каникулы теперь в витрине?
-- Должно вернуться 0
SELECT 
    COUNT(*) as количество_пропущенных_каникул
FROM rd.loan_holiday lh
WHERE NOT EXISTS (
    SELECT 1 FROM dm.loan_holiday_info lhi
    WHERE lhi.deal_rk = lh.deal_rk
      AND lhi.effective_from_date = lh.effective_from_date
);

-- 4. Пример данных из обновлённой витрины
SELECT * FROM dm.loan_holiday_info LIMIT 10;

-- 5. Просмотр логов выполнения
SELECT 
    log_id,
    table_name as имя_таблицы,
    operation_type as тип_операции,
    start_time as время_начала,
    end_time as время_окончания,
    rows_affected as количество_записей,
    status as статус
FROM logs.etl_log
WHERE operation_type = 'ОБНОВЛЕНИЕ'
ORDER BY log_id DESC
LIMIT 5;

-- 6. Сравнение количества записей до и после (для отчёта)
-- Показывает динамику изменения количества записей
SELECT 
    start_time as время_загрузки,
    rows_affected as количество_записей,
    status as статус
FROM logs.etl_log
WHERE operation_type = 'ОБНОВЛЕНИЕ'
ORDER BY start_time DESC
LIMIT 5;