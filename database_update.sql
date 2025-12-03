-- Add topic field to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS topic VARCHAR(100) UNIQUE;

-- Add guardian_id and topic to sos_alerts table
ALTER TABLE sos_alerts ADD COLUMN IF NOT EXISTS guardian_id INTEGER REFERENCES users(id);
ALTER TABLE sos_alerts ADD COLUMN IF NOT EXISTS topic VARCHAR(100);

-- Verify changes
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'users';
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sos_alerts';
