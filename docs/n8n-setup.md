
## 3.  Настройка n8n и workflow

### Переменные окружения n8n

В файле `/opt/beget/n8n/docker-compose.yml` в секции `x-shared: &shared` добавить:

* `N8N_ENABLE_UNSAFE_CORE_NODES=true`
* `NODES_EXCLUDE=[]`
* `N8N_RESTRICT_FILE_ACCESS_TO=/verification`

### Настройка volumes 

В в секции `x-shared: &shared` добавить volume:

* `/home/admeen/verification:/verification`

### Перезапуск n8n

Выполнить:

* `docker-compose down`
* `docker-compose up -d`

### Импорт workflow в n8n

* Импортировать из файла `linux lab teacher.json`
* Импортировать из файла `linux lab.json`
* Опубликовать оба workflow

### Почтовые уведомления (если нужно)

* Настроить SMTP/почту в n8n
* Сохранить данные в Credentials
