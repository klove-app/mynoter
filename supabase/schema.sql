-- ==========================================
-- Ванькины Заметки — Схема БД (Railway PostgreSQL)
-- ==========================================

-- 1. Папки для организации заметок (и книги)
CREATE TABLE IF NOT EXISTS folders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id UUID REFERENCES folders(id) ON DELETE CASCADE,
    type TEXT NOT NULL DEFAULT 'folder',
    description TEXT DEFAULT '',
    target_word_count INT,
    cover_image_url TEXT,
    genre TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Заметки (и главы книг)
CREATE TABLE IF NOT EXISTS notes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL DEFAULT '',
    content TEXT DEFAULT '',
    folder_id UUID REFERENCES folders(id) ON DELETE SET NULL,
    is_voice_note BOOLEAN DEFAULT false,
    audio_url TEXT,
    transcription_raw TEXT,
    sort_order INT DEFAULT 0,
    synopsis TEXT DEFAULT '',
    status TEXT DEFAULT 'draft',
    word_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_notes_folder ON notes(folder_id);
CREATE INDEX IF NOT EXISTS idx_notes_created ON notes(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_folders_parent ON folders(parent_id);
CREATE INDEX IF NOT EXISTS idx_notes_sort ON notes(folder_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_folders_type ON folders(type);

-- 4. Функция автообновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Триггеры автообновления
DROP TRIGGER IF EXISTS set_notes_updated_at ON notes;
CREATE TRIGGER set_notes_updated_at
    BEFORE UPDATE ON notes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_folders_updated_at ON folders;
CREATE TRIGGER set_folders_updated_at
    BEFORE UPDATE ON folders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
