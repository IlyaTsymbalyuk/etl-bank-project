-- Задание 2.3: Анализ некорректных данных в витрине
-- Проверяем, где account_in_sum не равен account_out_sum предыдущего дня

-- Шаг 1: Находим записи, где баланс не сходится
-- account_in_sum текущего дня должен равняться account_out_sum предыдущего дня
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
    account_rk,
    effective_date,
    prev_account_out_sum as остаток_предыдущего_дня,
    account_in_sum as остаток_текущего_дня_утро,
    account_out_sum as остаток_текущего_дня_вечер,
    CASE 
        WHEN account_in_sum != prev_account_out_sum 
        THEN 'НЕ СХОДИТСЯ'
        ELSE 'СХОДИТСЯ'
    END as проверка_баланса
FROM balance_with_prev
WHERE prev_account_out_sum IS NOT NULL
ORDER BY account_rk, effective_date;

-- Шаг 2: Подсчитываем количество проблемных записей
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
    COUNT(*) as количество_проблемных_записей
FROM balance_with_prev
WHERE prev_account_out_sum IS NOT NULL
  AND account_in_sum != prev_account_out_sum;

-- Шаг 3: Смотрим примеры проблемных записей для понимания
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
    account_rk,
    effective_date,
    prev_account_out_sum as остаток_предыдущего_дня,
    account_in_sum as остаток_текущего_дня_утро,
    (account_in_sum - prev_account_out_sum) as разница
FROM balance_with_prev
WHERE prev_account_out_sum IS NOT NULL
  AND account_in_sum != prev_account_out_sum
LIMIT 20;