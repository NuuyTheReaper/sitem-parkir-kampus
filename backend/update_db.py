from sqlalchemy import create_engine, text
from core.config import settings

def update_database():
    engine = create_engine(settings.DATABASE_URL)
    with engine.connect() as conn:
        print("Checking for existing columns in 'users' table...")
        
        # Add is_flagged if it doesn't exist
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN is_flagged INTEGER DEFAULT 0"))
            print("Added 'is_flagged' column to users.")
        except Exception as e:
            print(f"Column 'is_flagged' might already exist: {e}")

        # Add flag_reason if it doesn't exist
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN flag_reason VARCHAR(255)"))
            print("Added 'flag_reason' column to users.")
        except Exception as e:
            print(f"Column 'flag_reason' might already exist: {e}")

        print("Updating 'announcements' table...")
        try:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS announcements (
                    id INTEGER PRIMARY KEY AUTO_INCREMENT,
                    message VARCHAR(500) NOT NULL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    expires_at DATETIME NULL,
                    sender_id INTEGER NOT NULL,
                    FOREIGN KEY (sender_id) REFERENCES users(id)
                )
            """))
            # In case table exists but column doesn't
            try:
                conn.execute(text("ALTER TABLE announcements ADD COLUMN expires_at DATETIME NULL"))
                print("Added 'expires_at' column to announcements.")
            except:
                pass
            print("Table 'announcements' updated.")
        except Exception as e:
            print(f"Error updating announcements table: {e}")
            
        print("Updating 'emergency_guests' table...")
        try:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS emergency_guests (
                    id INTEGER PRIMARY KEY AUTO_INCREMENT,
                    nama VARCHAR(100) NOT NULL,
                    plat_nomor VARCHAR(50) NOT NULL,
                    alasan VARCHAR(255) NOT NULL,
                    waktu_masuk DATETIME DEFAULT CURRENT_TIMESTAMP,
                    waktu_keluar DATETIME NULL,
                    petugas_masuk_id INTEGER NOT NULL,
                    petugas_keluar_id INTEGER NULL,
                    status VARCHAR(20) DEFAULT 'di_dalam',
                    FOREIGN KEY (petugas_masuk_id) REFERENCES users(id),
                    FOREIGN KEY (petugas_keluar_id) REFERENCES users(id)
                )
            """))
            print("Table 'emergency_guests' updated.")
        except Exception as e:
            print(f"Error updating emergency_guests table: {e}")
            
        print("Updating 'access_requests' table...")
        try:
            conn.execute(text("ALTER TABLE access_requests MODIFY user_id INTEGER NULL"))
            conn.execute(text("ALTER TABLE access_requests MODIFY vehicle_id INTEGER NULL"))
            try:
                conn.execute(text("ALTER TABLE access_requests ADD COLUMN emergency_guest_id INTEGER NULL"))
                conn.execute(text("ALTER TABLE access_requests ADD FOREIGN KEY (emergency_guest_id) REFERENCES emergency_guests(id)"))
                print("Added 'emergency_guest_id' to access_requests.")
            except Exception as e:
                print(f"emergency_guest_id might already exist: {e}")
        except Exception as e:
            print(f"Error modifying access_requests: {e}")

        print("Updating 'parking_logs' table...")
        try:
            conn.execute(text("ALTER TABLE parking_logs ADD COLUMN emergency_guest_id INTEGER NULL"))
            conn.execute(text("ALTER TABLE parking_logs ADD FOREIGN KEY (emergency_guest_id) REFERENCES emergency_guests(id)"))
            print("Added 'emergency_guest_id' column to parking_logs.")
        except Exception as e:
            print(f"Column 'emergency_guest_id' might already exist or failed: {e}")
        
        conn.commit()

if __name__ == "__main__":
    update_database()
