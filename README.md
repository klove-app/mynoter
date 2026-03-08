# Ванькины Заметки

iOS приложение для личных заметок с rich-text редактором и голосовым вводом с AI-форматированием.

## Возможности

- Текстовые заметки с форматированием (bold, italic, заголовки, списки, highlight, code)
- Голосовые заметки: запись → транскрипция (Whisper) → AI-форматирование (Claude)
- Организация по папкам
- Поиск по заметкам
- Автосохранение
- Тёмная тема

## Архитектура

```
iOS App (SwiftUI) → REST API (Express.js, Railway) → PostgreSQL (Railway)
                                   ↓
                        Whisper API + Claude API
```

## Стек

- **iOS**: SwiftUI (iOS 17+), URLSession
- **API**: Express.js (Node.js)
- **DB**: PostgreSQL (Railway)
- **STT**: OpenAI Whisper API
- **AI**: Anthropic Claude API
- **Деплой**: Railway

## Настройка

### 1. PostgreSQL (уже на Railway)

БД уже создана. Если нужно пересоздать таблицы:

```bash
psql $DATABASE_URL -f supabase/schema.sql
```

### 2. API Сервер

```bash
cd api
npm install

# Задай переменные окружения
export DATABASE_URL="postgresql://..."
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."

npm start
```

### 3. Деплой API на Railway

1. Создай новый сервис в Railway из папки `api/`
2. Задай переменные окружения: `DATABASE_URL`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`
3. Railway задеплоит автоматически

### 4. Xcode проект

```bash
brew install xcodegen
cd ванькинызаметки
xcodegen generate
open VankinyZametki.xcodeproj
```

### 5. Конфигурация iOS

В `VankinyZametki/Utils/Config.swift` укажи URL задеплоенного API:

```swift
static let apiBaseURL = "https://your-api.up.railway.app"
```

## Структура

```
api/                                   — REST API сервер
├── server.js                          — Express app, роуты
├── db.js                              — PostgreSQL пул
├── routes/
│   ├── notes.js                       — CRUD заметок
│   ├── folders.js                     — CRUD папок
│   ├── audio.js                       — Upload/serve аудио
│   └── voice.js                       — Whisper + Claude обработка
├── Dockerfile                         — Деплой на Railway
└── package.json

VankinyZametki/                        — iOS приложение
├── App/                               — Entry point, TabView
├── Models/                            — Note, Folder
├── Views/                             — Экраны (список, редактор, рекордер, папки)
├── Components/                        — Rich text editor, тулбар, аудио-плеер
├── Services/                          — APIService, NoteStore, FolderStore
├── Utils/                             — HTML конвертер, конфигурация
└── Resources/                         — Assets, Info.plist

supabase/
└── schema.sql                         — SQL схема
```
