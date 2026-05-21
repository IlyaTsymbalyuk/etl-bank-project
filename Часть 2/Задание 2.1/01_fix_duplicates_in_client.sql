-- Задание 2.1: Устранение дублей в витрине dm.client

-- Шаг 1: Анализ дублей - находим все дублирующиеся записи

-- Запрос для обнаружения дублей
-- Группируем по ключевым полям (client_rk, effective_from_date) и находим те, у которых больше 1 записи
SELECT 
    client_rk,
    effective_from_date,
    COUNT(*) as duplicate_count
FROM dm.client
GROUP BY client_rk, effective_from_date
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, client_rk, effective_from_date;

-- Подробный просмотр дублей с указанием всех полей для анализа
-- Этот запрос помогает понять, какие именно строки дублируются и чем они отличаются
SELECT 
    c1.client_rk,
    c1.effective_from_date,
    c1.effective_to_date,
    c1.counterparty_type_cd,
    c1.black_list_flag,
    c1.client_id,
    c1.client_name
FROM dm.client c1
WHERE EXISTS (
    SELECT 1
    FROM dm.client c2
    WHERE c2.client_rk = c1.client_rk
      AND c2.effective_from_date = c1.effective_from_date
      AND c2.ctid > c1.ctid  -- ctid - физический идентификатор строки в PostgreSQL
)
ORDER BY c1.client_rk, c1.effective_from_date;

-- Шаг 2: Удаление дублей

-- Способ 1: Удаляем дубли с помощью CTID (физический адрес строки)
-- Оставляем одну запись для каждой комбинации (client_rk, effective_from_date)

WITH duplicates AS (
    SELECT 
        ctid,  -- уникальный идентификатор строки в PostgreSQL
        client_rk,
        effective_from_date,
        ROW_NUMBER() OVER (
            PARTITION BY client_rk, effective_from_date 
            ORDER BY ctid
        ) as row_num
    FROM dm.client
)
DELETE FROM dm.client
WHERE ctid IN (
    SELECT ctid 
    FROM duplicates 
    WHERE row_num > 1
);

-- Шаг 3: Проверка результата

-- Проверяем, что дублей больше нет
-- Должно вернуть 0 строк
SELECT 
    client_rk,
    effective_from_date,
    COUNT(*) as duplicate_count
FROM dm.client
GROUP BY client_rk, effective_from_date
HAVING COUNT(*) > 1;

-- Подсчитываем общее количество записей после очистки
SELECT COUNT(*) as total_records_after_cleanup FROM dm.client;

-- Показываем статистику по клиентам (сколько версий у каждого клиента)
SELECT 
    client_rk,
    COUNT(*) as versions_count,
    MIN(effective_from_date) as first_version_date,
    MAX(effective_to_date) as last_version_date
FROM dm.client
GROUP BY client_rk
ORDER BY versions_count DESC, client_rk
LIMIT 20;

-- Шаг 4: Создаём проверочную таблицу для демонстрации (опционально)

-- Если нужно сохранить информацию об удалённых дублях для отчётности
CREATE TABLE IF NOT EXISTS LOGS.CLIENT_DUPLICATES_LOG (
    log_id SERIAL PRIMARY KEY,
    client_rk NUMERIC,
    effective_from_date DATE,
    effective_to_date DATE,
    counterparty_type_cd VARCHAR(10),
    black_list_flag VARCHAR(1),
    client_id VARCHAR(50),
    client_name VARCHAR(200),
    deletion_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Сохраняем информацию об удалённых дублях (если нужно)
-- Раскомментировать при необходимости
/*
INSERT INTO LOGS.CLIENT_DUPLICATES_LOG (client_rk, effective_from_date, effective_to_date, counterparty_type_cd, black_list_flag, client_id, client_name)
SELECT 
    c.client_rk,
    c.effective_from_date,
    c.effective_to_date,
    c.counterparty_type_cd,
    c.black_list_flag,
    c.client_id,
    c.client_name
FROM dm.client c
WHERE (c.client_rk, c.effective_from_date) IN (
    SELECT client_rk, effective_from_date
    FROM dm.client
    GROUP BY client_rk, effective_from_date
    HAVING COUNT(*) > 1
)
AND c.ctid NOT IN (
    SELECT MIN(ctid)
    FROM dm.client
    GROUP BY client_rk, effective_from_date
);
*/