import os
import uuid
from flask import current_app

class BaseStorageService:
    def save_file(self, file_data, filename, mime_type) -> str:
        """
        Saves the file data and returns a unique path/key string.
        """
        raise NotImplementedError()
        
    def delete_file(self, filepath) -> bool:
        """
        Deletes the file from storage.
        """
        raise NotImplementedError()

    def get_absolute_path(self, filepath) -> str:
        """
        Returns the absolute local path to access/serve the file.
        """
        raise NotImplementedError()

class LocalStorageService(BaseStorageService):
    def __init__(self, upload_folder):
        self.upload_folder = upload_folder
        os.makedirs(self.upload_folder, exist_ok=True)
        
    def save_file(self, file_data, filename, mime_type) -> str:
        # Ensure a unique, collision-free name
        ext = os.path.splitext(filename)[1]
        unique_name = f"{uuid.uuid4()}{ext}"
        relative_path = os.path.join("reports", unique_name)
        absolute_path = self.get_absolute_path(relative_path)
        
        # Ensure subdirectory exists
        os.makedirs(os.path.dirname(absolute_path), exist_ok=True)
        
        # Save the file data
        if hasattr(file_data, 'save'):
            # If it's a Flask FileStorage object
            file_data.save(absolute_path)
        else:
            # If it's raw bytes
            with open(absolute_path, 'wb') as f:
                f.write(file_data)
                
        # Return path relative to the uploads folder
        return relative_path.replace('\\', '/')
        
    def delete_file(self, filepath) -> bool:
        try:
            abs_path = self.get_absolute_path(filepath)
            if os.path.exists(abs_path):
                os.remove(abs_path)
                return True
        except Exception:
            pass
        return False
        
    def get_absolute_path(self, filepath) -> str:
        # Clean the filepath to prevent directory traversal
        clean_path = filepath.replace('\\', '/').lstrip('/')
        if '..' in clean_path:
            raise ValueError("Path traversal security violation detected")
        return os.path.join(self.upload_folder, clean_path)

_instance = None

def get_storage_service():
    global _instance
    if _instance is None:
        upload_folder = current_app.config.get('UPLOAD_FOLDER', 'uploads')
        _instance = LocalStorageService(upload_folder)
    return _instance
