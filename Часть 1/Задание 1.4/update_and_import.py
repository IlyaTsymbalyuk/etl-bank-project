# Скрипт для изменения данных в CSV и импорта в таблицу

import psycopg2
import csv
from datetime import datetime
from config import DB_CONFIG

CSV_ORIGINAL = "demo_f101_round_f_export.csv"   # исходный CSV
CSV_MODIFIED = "demo_f101_round_f_modified.csv" # изменённый CSV
LOG_PATH = "update_log.txt"

def log_message(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(f"{timestamp} - {message}\n")
    print(f"{timestamp} - {message}")

def modify_csv():
    """Читает CSV, изменяет некоторые значения, сохраняет новый файл"""
    log_message("Чтение оригинального CSV")
    
    # Проверяем, существует ли файл
    import os
    if not os.path.exists(CSV_ORIGINAL):
        log_message(f"Ошибка: файл {CSV_ORIGINAL} не найден. Сначала запустите export_to_csv.py")
        return None, None
    
    # Читаем CSV файл
    rows = []
    with open(CSV_ORIGINAL, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f, delimiter=';')
        headers = next(reader)  # сохраняем заголовки
        for row in reader:
            rows.append(row)
    
    log_message(f"Прочитано записей: {len(rows)}")
    
    print("Оригинальные данные (первые 3 строки):")
    for i in range(min(3, len(rows))):
        print(f"  Строка {i+1}: {rows[i][3]} - {rows[i][4]}, balance_in_total={rows[i][7]}, balance_out_total={rows[i][16]}")
    
    log_message("Внесение изменений")
    
    # Изменение 1: увеличиваем balance_in_total на 10% для первого счёта (30102)
    if len(rows) > 0:
        old_value = float(rows[0][7])  # balance_in_total
        new_value = old_value * 1.1
        rows[0][7] = f"{new_value:.2f}"  # округляем до 2 знаков
        log_message(f"Счёт {rows[0][3]}: balance_in_total было {old_value}, стало {new_value:.2f}")
    
    # Изменение 2: меняем balance_out_total для второго счёта (30109)
    if len(rows) > 1:
        old_value = rows[1][16]  # balance_out_total
        rows[1][16] = "999999.99"
        log_message(f"Счёт {rows[1][3]}: balance_out_total было {old_value}, стало 999999.99")
    
    # Изменение 3: меняем характеристику счёта для третьего счёта (30201)
    if len(rows) > 2:
        old_value = rows[2][4]  # characteristic
        rows[2][4] = "П" if old_value == "А" else "А"
        log_message(f"Счёт {rows[2][3]}: характеристика была {old_value}, стала {rows[2][4]}")
    
    # Сохраняем изменённый CSV
    with open(CSV_MODIFIED, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f, delimiter=';')
        writer.writerow(headers)
        writer.writerows(rows)
    
    log_message(f"Изменённый CSV сохранен в {CSV_MODIFIED}")
    
    print("Изменённые данные (первые 3 строки):")
    for i in range(min(3, len(rows))):
        print(f"  Строка {i+1}: {rows[i][3]} - {rows[i][4]}, balance_in_total={rows[i][7]}, balance_out_total={rows[i][16]}")
    
    return rows

def import_modified_csv(rows):
    """Импортирует изменённые данные в таблицу"""
    if rows is None:
        return
    
    log_message("Начало импорта изменённых данных")
    
    # Подключаемся к БД
    conn_string = f"host={DB_CONFIG['host']} port={DB_CONFIG['port']} dbname={DB_CONFIG['database']} user={DB_CONFIG['user']} password={DB_CONFIG['password']}"
    conn = psycopg2.connect(conn_string)
    log_message("Подключено к БД")
    
    cur = conn.cursor()
    
    # Очищаем таблицу перед загрузкой
    log_message("Очистка таблицы dm.demo_f101_round_f_v2")
    cur.execute("TRUNCATE TABLE dm.demo_f101_round_f_v2")
    
    inserted_count = 0
    
    # Преобразуем строки в нужные типы и вставляем
    for row in rows:
        # Преобразуем текстовые значения в числа
        converted_row = []
        for i, value in enumerate(row):
            if i >= 5:  # числовые колонки
                try:
                    converted_row.append(float(value))
                except:
                    converted_row.append(0.0)
            else:
                converted_row.append(value)
        
        cur.execute("""
            INSERT INTO dm.demo_f101_round_f_v2 VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, converted_row)
        inserted_count += 1
    
    # Сохраняем изменения
    conn.commit()
    log_message(f"Вставлено записей: {inserted_count}")
    
    # Проверяем результат
    cur.execute("SELECT ledger_account, balance_in_total, balance_out_total FROM dm.demo_f101_round_f_v2")
    print("Данные в БД после импорта:")
    for row in cur.fetchall():
        print(f"  Счёт: {row[0]}, Входящий остаток: {row[1]}, Исходящий остаток: {row[2]}")
    
    cur.close()
    conn.close()
    log_message("Импорт завершён")

if __name__ == "__main__":
    rows = modify_csv()
    import_modified_csv(rows)