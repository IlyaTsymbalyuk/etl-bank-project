-- Инициализация витрины остатков на 31 декабря 2017 года
-- Берём данные из DS.FT_BALANCE_F, так как справочник счетов не покрывает 2017 год

DELETE FROM DM.DM_ACCOUNT_BALANCE_F WHERE ON_DATE = '2017-12-31';

INSERT INTO DM.DM_ACCOUNT_BALANCE_F (ON_DATE, ACCOUNT_RK, BALANCE_OUT, BALANCE_OUT_RUB)
SELECT 
    ON_DATE,
    ACCOUNT_RK,
    BALANCE_OUT,
    BALANCE_OUT
FROM DS.FT_BALANCE_F 
WHERE ON_DATE = '2017-12-31';

-- Проверка количества инициализированных записей
SELECT '2017-12-31' as init_date, COUNT(*) as records_count 
FROM DM.DM_ACCOUNT_BALANCE_F 
WHERE ON_DATE = '2017-12-31';