-- Задание 2.3: Перестроение витрины dm.account_balance_turnover
-- Используем исправленный прототип account_balance_turnover_prototype.sql

-- Шаг 1: Очищаем витрину перед перезагрузкой
TRUNCATE TABLE dm.account_balance_turnover;

-- Шаг 2: Перестраиваем витрину
-- Прототип из файла account_balance_turnover_prototype.sql был:
-- SELECT a.account_rk, COALESCE(dc.currency_name, '-1') AS currency_name,
--        a.department_rk, ab.effective_date, ab.account_in_sum, ab.account_out_sum
-- FROM rd.account a
-- LEFT JOIN rd.account_balance ab ON a.account_rk = ab.account_rk
-- LEFT JOIN dm.dict_currency dc ON a.currency_cd = dc.currency_cd

-- Расширенная версия с правильным порядком сортировки
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

-- Шаг 3: Проверка результата
SELECT 'Количество записей в витрине' as статус, COUNT(*) as количество
FROM dm.account_balance_turnover;

-- Пример данных из витрины
SELECT * FROM dm.account_balance_turnover LIMIT 10;