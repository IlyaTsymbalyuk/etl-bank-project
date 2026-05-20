# Скрипт для импорта данных из CSV файла в новую таблицу

import psycopg2  # для подключения к PostgreSQL
import csv       # для чтения CSV файла
from datetime import datetime  # для временных меток в логах
from config import DB_CONFIG   # настройки подключения

CSV_PATH = "demo_f101_round_f_export.csv"  # откуда читаем CSV
LOG_PATH = "import_log.txt"                 # куда пишем лог

def log_message(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(f"{timestamp} - {message}\n")
    print(f"{timestamp} - {message}")

def create_table_v2(conn):
    """Создаёт таблицу-копию для импорта данных"""
    log_message("Создание таблицы dm.demo_f101_round_f_v2")
    
    cur = conn.cursor()
    
    # Удаляем старую таблицу, если есть
    cur.execute("DROP TABLE IF EXISTS dm.demo_f101_round_f_v2")
    
    # Создаём новую таблицу с такой же структурой
    cur.execute("""
        CREATE TABLE dm.demo_f101_round_f_v2 (
            from_date DATE,
            to_date DATE,
            chapter CHAR(1),
            ledger_account CHAR(5),
            characteristic CHAR(1),
            balance_in_rub NUMERIC(30,8),
            balance_in_val NUMERIC(30,8),
            balance_in_total NUMERIC(30,8),
            turn_deb_rub NUMERIC(30,8),
            turn_deb_val NUMERIC(30,8),
            turn_deb_total NUMERIC(30,8),
            turn_cre_rub NUMERIC(30,8),
            turn_cre_val NUMERIC(30,8),
            turn_cre_total NUMERIC(30,8),
            balance_out_rub NUMERIC(30,8),
            balance_out_val NUMERIC(30,8),
            balance_out_total NUMERIC(30,8)
        )
    """)
    
    conn.commit()
    cur.close()
    log_message("Таблица dm.demo_f101_round_f_v2 создана")

def import_from_csv():
    log_message("Начало импорта")
    
    # Проверяем, существует ли CSV файл
    import os
    if not os.path.exists(CSV_PATH):
        log_message(f"Ошибка: файл {CSV_PATH} не найден. Сначала запустите export_to_csv.py")
        return
    
    log_message(f"Чтение файла {CSV_PATH}")
    
    # Читаем CSV файл
    rows = []
    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f, delimiter=';')
        headers = next(reader)  # пропускаем заголовки
        for row in reader:
            # Преобразуем строки в числа где нужно
            converted_row = []
            for i, value in enumerate(row):
                if i >= 5:  # числовые колонки начиная с индекса 5
                    try:
                        converted_row.append(float(value))
                    except:
                        converted_row.append(None)
                else:
                    converted_row.append(value)  # текстовые колонки оставляем как есть
            rows.append(converted_row)
    
    log_message(f"Прочитано записей: {len(rows)}")
    
    # Подключаемся к БД
    conn_string = f"host={DB_CONFIG['host']} port={DB_CONFIG['port']} dbname={DB_CONFIG['database']} user={DB_CONFIG['user']} password={DB_CONFIG['password']}"
    conn = psycopg2.connect(conn_string)
    log_message("Подключено к БД")
    
    # Создаём таблицу для импорта
    create_table_v2(conn)
    
    cur = conn.cursor()
    inserted_count = 0
    
    # Вставляем каждую строку в таблицу
    for row in rows:
        cur.execute("""
            INSERT INTO dm.demo_f101_round_f_v2 VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, row)
        inserted_count += 1
    
    # Сохраняем изменения
    conn.commit()
    log_message(f"Вставлено записей: {inserted_count}")
    
    # Проверяем результат
    cur.execute("SELECT COUNT(*) FROM dm.demo_f101_round_f_v2")
    db_count = cur.fetchone()[0]
    log_message(f"Проверка: в таблице {db_count} записей")
    
    # Показываем содержимое таблицы
    cur.execute("SELECT ledger_account, balance_in_total, balance_out_total FROM dm.demo_f101_round_f_v2")
    print("Содержимое таблицы после импорта:")
    for row in cur.fetchall():
        print(f"  Счёт: {row[0]}, Входящий остаток: {row[1]}, Исходящий остаток: {row[2]}")
    
    cur.close()
    conn.close()
    log_message("Импорт завершен")

if __name__ == "__main__":
    import_from_csv()