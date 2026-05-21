-- Задание 2.3: Определение корректных значений
-- Пункт 1: Если account_in_sum и account_out_sum предыдущего дня отличаются,
-- корректным выбирается account_out_sum предыдущего дня

-- Запрос показывает, какие значения должны быть вместо некорректных
WITH balance_with_prev AS (
    SELECT 
        account_rk,
        effective_date,
        account_in_sum as было_утро,
        account_out_sum as было_вечер,
        LAG(account_out_sum) OVER (PARTITION BY account_rk ORDER BY effective_date) as остаток_предыдущего_вечера
    FROM rd.account_balance
)
SELECT 
    account_rk,
    effective_date,
    было_утро,
    остаток_предыдущего_вечера as должно_быть_утро,
    было_вечер,
    CASE 
        WHEN было_утро != остаток_предыдущего_вечера 
        THEN 'НУЖНО ИСПРАВИТЬ'
        ELSE 'ВЕРНО'
    END as статус
FROM balance_with_prev
WHERE остаток_предыдущего_вечера IS NOT NULL
ORDER BY account_rk, effective_date;

-- Пункт 2: Если account_in_sum правильная, а account_out_sum предыдущего дня некорректна,
-- корректным для account_out_sum выбирается account_in_sum текущего дня

-- Этот запрос показывает ситуации, где проблема в предыдущем дне
WITH balance_with_next AS (
    SELECT 
        account_rk,
        effective_date,
        account_in_sum as было_утро,
        account_out_sum as было_вечер,
        LEAD(account_in_sum) OVER (PARTITION BY account_rk ORDER BY effective_date) as утро_следующего_дня
    FROM rd.account_balance
)
SELECT 
    account_rk,
    effective_date,
    было_утро,
    было_вечер,
    утро_следующего_дня as должно_быть_вечер,
    CASE 
        WHEN было_вечер != утро_следующего_дня 
        THEN 'НУЖНО ИСПРАВИТЬ'
        ELSE 'ВЕРНО'
    END as статус
FROM balance_with_next
WHERE утро_следующего_дня IS NOT NULL
ORDER BY account_rk, effective_date;