from supabase import create_client, Client

SUPABASE_URL = 'https://sdjytgbojqslkfwfxlvs.supabase.co'
SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNkanl0Z2JvanFzbGtmd2Z4bHZzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA0NjEwNjUsImV4cCI6MjA1NjAzNzA2NX0.IAFreOpeUF0qxKyWaEbpyG3eQPWS3F58XisraV_Z8S8'

supabase: Client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)

def get_chapters():
    response = supabase.table('chemistry_chapter').select('chapter_name').execute()
    if response.error:
        raise Exception(response.error.message)
    return response.data 

def upload_image_to_storage(image_data: bytes, image_name: str):
    response = supabase.storage.from_('mistakes').upload(image_name, image_data)
    if response.error:
        raise Exception(response.error.message)
    return response.data['Key'] 