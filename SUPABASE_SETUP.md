# QuickParking Supabase Setup

## 1. Create the project

Create a project at <https://supabase.com/dashboard>. Wait until the database is ready.

## 2. Install the database schema

1. Open **SQL Editor** in the Supabase dashboard.
2. Create a new query.
3. Paste the complete contents of `supabase/schema.sql`.
4. Select **Run**.

The script creates all tables, indexes, Row Level Security policies, Realtime configuration, the `parking-images` Storage bucket, and atomic booking functions.

## 3. Configure email authentication

Email/password authentication is enabled by default. For a classroom demonstration, open **Authentication > Providers > Email** and disable **Confirm email**. For production, leave confirmation enabled and configure SMTP and redirect URLs.

## 4. Add local project credentials

Copy `supabase.env.example.json` to `supabase.env.json`. Get the values from the Supabase project **Connect** dialog or **Project Settings > API Keys**:

```json
{
  "SUPABASE_URL": "https://your-project-ref.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_your_key"
}
```

Use the publishable/anon client key. Never put the `service_role` or secret key in a Flutter application.

## 5. Run QuickParking

```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=supabase.env.json
```

For Windows, first enable Windows Developer Mode because Flutter plugins require symbolic links:

```powershell
start ms-settings:developers
flutter run -d windows --dart-define-from-file=supabase.env.json
```

For Android, start an emulator or connect a device, then use its ID from `flutter devices`:

```powershell
flutter run -d <device-id> --dart-define-from-file=supabase.env.json
```

## 6. Create an admin

Create a user from **Authentication > Users > Add user**. Auto-confirm the account for a demo. Then run this in SQL Editor, replacing the values:

```sql
insert into public.admins (id, name, email, phone)
select id, 'Main Admin', email, '9999999999'
from auth.users
where email = 'admin@gmail.com'
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  phone = excluded.phone;
```

The database trigger removes the corresponding customer profile when the admin profile is created.

## 7. Add demonstration data

Sign in as an admin, open **Settings**, then select **Seed Demo Dataset**. The admin-only database function safely creates sample locations and slots only when the location table is empty.

## Troubleshooting

- **Supabase setup required:** `supabase.env.json` is missing, has placeholders, or was not supplied with `--dart-define-from-file`.
- **Table/RPC not found:** run the full `supabase/schema.sql` file.
- **Permission denied / RLS error:** confirm the schema completed without SQL errors and the user is signed in.
- **Admin login denied:** confirm the Auth user also has a row in `public.admins` with the same UUID.
- **No live updates:** verify the tables are enabled under **Database > Publications > supabase_realtime**.
