-- Задание 2.3: Исправление данных в таблице rd.account_balance
-- Исправляем account_in_sum на основе account_out_sum предыдущего дня

-- Шаг 1: Создаём резервную копию перед исправлением (на всякий случай)
CREATE TABLE IF NOT EXISTS rd.account_balance_backup AS 
SELECT * FROM rd.account_balance;

-- Шаг 2: Исправляем account_in_sum
-- Обновляем account_in_sum текущего дня значением account_out_sum предыдущего дня
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

-- Шаг 3: Исправляем account_out_sum
-- Обновляем account_out_sum предыдущего дня значением account_in_sum текущего дня
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

-- Шаг 4: Проверка результата исправления
-- Теперь balance_in_sum должен равняться balance_out_sum предыдущего дня
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
    COUNT(*) as количество_проблемных_записей_после_исправления
FROM balance_with_prev
WHERE prev_account_out_sum IS NOT NULL
  AND account_in_sum != prev_account_out_sum;

-- Шаг 5: Показываем пример исправленных данных
WITH balance_with_prev AS (
    SELECT 
        account_rk,
        effective_date,
        account_in_sum,
        account_out_sum,
        LAG(account_out_sum) OVER (PARTITION BY account_rk ORDER BY effective_date) as prev_account_out_sum,
        LAG(effective_date) OVER (PARTITION BY account_rk ORDER BY effective_date) as prev_date
    FROM rd.account_balance
)
SELECT 
    account_rk,
    prev_date as дата_предыдущего_дня,
    prev_account_out_sum as остаток_предыдущего_дня,
    effective_date as текущая_дата,
    account_in_sum as остаток_текущего_дня_утро,
    account_out_sum as остаток_текущего_дня_вечер,
    CASE 
        WHEN account_in_sum = prev_account_out_sum 
        THEN 'БАЛАНС СХОДИТСЯ'
        ELSE 'БАЛАНС НЕ СХОДИТСЯ'
    END as проверка
FROM balance_with_prev
WHERE prev_account_out_sum IS NOT NULL
LIMIT 20;