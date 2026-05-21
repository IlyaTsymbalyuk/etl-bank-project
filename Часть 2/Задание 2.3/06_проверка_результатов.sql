-- Задание 2.3: Проверка результатов после обновления

-- 1. Проверка, что баланс сходится (account_in_sum = account_out_sum предыдущего дня)
WITH balance_with_prev AS (
    SELECT 
        account_rk,
        effective_date,
        account_in_sum,
        account_out_sum,
        LAG(account_out_sum) OVER (PARTITION BY account_rk ORDER BY effective_date) as prev_account_out_sum
    FROM rd.account_balance
)
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN 'ВСЕ ЗАПИСИ КОРРЕКТНЫ'
        ELSE 'ЕСТЬ ПРОБЛЕМНЫЕ ЗАПИСИ'
    END as статус,
    COUNT(*) as количество_проблемных_записей
FROM balance_with_prev
WHERE prev_account_out_sum IS NOT NULL
  AND account_in_sum != prev_account_out_sum;

-- 2. Количество записей в витрине
SELECT 'Количество записей в витрине' as показатель, COUNT(*) as значение
FROM dm.account_balance_turnover;

-- 3. Пример данных из витрины
SELECT * FROM dm.account_balance_turnover LIMIT 10;

-- 4. Проверка цепочки остатков по конкретному счёту
-- Выберите любой account_rk из таблицы
SELECT 
    account_rk,
    effective_date,
    account_in_sum,
    account_out_sum,
    LAG(account_out_sum) OVER (ORDER BY effective_date) as prev_out_sum,
    CASE 
        WHEN account_in_sum = LAG(account_out_sum) OVER (ORDER BY effective_date) 
        THEN 'СХОДИТСЯ'
        ELSE 'НЕ СХОДИТСЯ'
    END as проверка
FROM dm.account_balance_turnover
WHERE account_rk = (SELECT account_rk FROM dm.account_balance_turnover LIMIT 1)
ORDER BY effective_date;

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
WHERE operation_type = 'ОБНОВЛЕНИЕ_ВИТРИНЫ'
ORDER BY log_id DESC
LIMIT 5;