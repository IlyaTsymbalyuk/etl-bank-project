# Задание 1.4: Экспорт и импорт данных в CSV

## Описание
Скрипты для выгрузки витрины DM.DM_F101_ROUND_F в CSV и обратного импорта.

## Файлы
- config.py - настройки подключения к БД
- requirements.txt - зависимости Python
- export_to_csv.py - экспорт данных в CSV
- import_from_csv.py - импорт из CSV в новую таблицу
- update_and_import.py - изменение CSV и импорт

## Как запустить

1. Установить зависимости:
   pip install -r requirements.txt

2. Настроить config.py (указать пароль от БД)

3. Экспорт:
   python export_to_csv.py

4. Импорт:
   python import_from_csv.py

5. Изменение и импорт:
   python update_and_import.py

## Что получается в результате
- export_to_csv.py создает файл dm_f101_round_f_export.csv
- import_from_csv.py создает таблицу DM.DM_F101_ROUND_F_V2
- update_and_import.py изменяет данные и загружает их в таблицу

## Логи
Все операции записываются в файлы .txt в папке со скриптами.