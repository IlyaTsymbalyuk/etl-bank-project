# Скрипт для создания демонстрационной таблицы с тестовыми данными

import psycopg2  # библиотека для подключения к PostgreSQL
from config import DB_CONFIG  # импортируем настройки подключения

# Подключаемся к базе данных
conn_string = f"host={DB_CONFIG['host']} port={DB_CONFIG['port']} dbname={DB_CONFIG['database']} user={DB_CONFIG['user']} password={DB_CONFIG['password']}"
conn = psycopg2.connect(conn_string)
cur = conn.cursor()

# Создаём схему dm, если её нет
cur.execute("CREATE SCHEMA IF NOT EXISTS dm")
print("Схема dm создана или уже существует")

# Удаляем старую таблицу, если она есть
cur.execute("DROP TABLE IF EXISTS dm.demo_f101_round_f")
print("Старая таблица удалена")

# Создаём новую таблицу с нужными колонками
cur.execute("""
    CREATE TABLE dm.demo_f101_round_f (
        from_date DATE,                      -- дата начала периода
        to_date DATE,                        -- дата окончания периода
        chapter CHAR(1),                     -- глава баланса (1,2,3,4)
        ledger_account CHAR(5),              -- номер балансового счёта
        characteristic CHAR(1),              -- характеристика счёта (А или П)
        balance_in_rub NUMERIC(30,8),        -- входящий остаток в рублях
        balance_in_val NUMERIC(30,8),        -- входящий остаток в валюте
        balance_in_total NUMERIC(30,8),      -- входящий остаток итого
        turn_deb_rub NUMERIC(30,8),          -- дебетовый оборот в рублях
        turn_deb_val NUMERIC(30,8),          -- дебетовый оборот в валюте
        turn_deb_total NUMERIC(30,8),        -- дебетовый оборот итого
        turn_cre_rub NUMERIC(30,8),          -- кредитовый оборот в рублях
        turn_cre_val NUMERIC(30,8),          -- кредитовый оборот в валюте
        turn_cre_total NUMERIC(30,8),        -- кредитовый оборот итого
        balance_out_rub NUMERIC(30,8),       -- исходящий остаток в рублях
        balance_out_val NUMERIC(30,8),       -- исходящий остаток в валюте
        balance_out_total NUMERIC(30,8)      -- исходящий остаток итого
    )
""")
print("Таблица dm.demo_f101_round_f создана")

# Вставляем 3 тестовые записи
cur.execute("""
    INSERT INTO dm.demo_f101_round_f VALUES 
    ('2018-01-01', '2018-01-31', '1', '30102', 'А', 
     100000.00, 0.00, 100000.00, 
     50000.00, 0.00, 50000.00, 
     30000.00, 0.00, 30000.00, 
     120000.00, 0.00, 120000.00),
    
    ('2018-01-01', '2018-01-31', '1', '30109', 'П', 
     0.00, 50000.00, 50000.00, 
     0.00, 25000.00, 25000.00, 
     0.00, 15000.00, 15000.00, 
     0.00, 60000.00, 60000.00),
    
    ('2018-01-01', '2018-01-31', '2', '30201', 'А', 
     75000.00, 0.00, 75000.00, 
     20000.00, 0.00, 20000.00, 
     10000.00, 0.00, 10000.00, 
     85000.00, 0.00, 85000.00)
""")

# Сохраняем изменения в базе данных
conn.commit()
print("Тестовые данные вставлены")

# Проверяем, сколько записей в таблице
cur.execute("SELECT COUNT(*) FROM dm.demo_f101_round_f")
count = cur.fetchone()[0]
print(f"В таблице {count} записей")

# Показываем содержимое таблицы
cur.execute("SELECT * FROM dm.demo_f101_round_f")
rows = cur.fetchall()
print("Содержимое таблицы:")
for row in rows:
    print(f"  Счёт: {row[3]}, Характеристика: {row[4]}, Входящий остаток: {row[7]}, Исходящий остаток: {row[16]}")

# Закрываем соединение
cur.close()
conn.close()
print("Готово!")