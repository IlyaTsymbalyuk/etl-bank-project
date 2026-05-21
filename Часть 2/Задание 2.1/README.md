# Задание 2.1: Устранение дублей в витрине dm.client

## Описание проблемы
В витрине dm.client обнаружены дублирующиеся записи с одинаковыми значениями ключевых полей:
- client_rk (уникальный код клиента)
- effective_from_date (дата начала действия записи)

Это приводит к некорректным результатам при построении отчетов.

## Решение

### Файлы
| Файл | Назначение |
|------|------------|
| 01_fix_duplicates_in_client.sql | Обнаружение и удаление дублей |
| 02_prevent_future_duplicates.sql | Предотвращение появления новых дублей |

### Порядок выполнения

1. Выполнить 01_fix_duplicates_in_client.sql
2. Проверить, что дубли удалены
3. Выполнить 02_prevent_future_duplicates.sql для добавления ограничения

### Запросы для проверки

```sql
-- Проверка дублей (должно быть 0 строк)
SELECT client_rk, effective_from_date, COUNT(*)
FROM dm.client
GROUP BY client_rk, effective_from_date
HAVING COUNT(*) > 1;

-- Общая статистика
SELECT COUNT(*) as total_records FROM dm.client;