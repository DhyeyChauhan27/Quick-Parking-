$ErrorActionPreference = 'Stop'

$projectRef = 'glqbsxaqdotctthqjmkq'
$projectUrl = "https://$projectRef.supabase.co"

$keysJson = & npx supabase@latest projects api-keys `
  --project-ref $projectRef `
  --output json `
  --output-format text `
  --agent no
if ($LASTEXITCODE -ne 0) {
  throw 'Could not retrieve Supabase API keys.'
}

$keys = $keysJson | ConvertFrom-Json
$serviceKey = ($keys | Where-Object name -eq 'service_role').api_key
$publishableKey = ($keys | Where-Object type -eq 'publishable' | Select-Object -First 1).api_key
if ([string]::IsNullOrWhiteSpace($serviceKey) -or [string]::IsNullOrWhiteSpace($publishableKey)) {
  throw 'Required Supabase API keys were not returned.'
}

$adminHeaders = @{
  apikey = $serviceKey
  Authorization = "Bearer $serviceKey"
}

function Get-SupabaseUser([string] $email) {
  $response = Invoke-RestMethod `
    -Uri "$projectUrl/auth/v1/admin/users?page=1&per_page=1000" `
    -Method Get `
    -Headers $adminHeaders
  return @($response.users) | Where-Object email -eq $email | Select-Object -First 1
}

function Ensure-SupabaseUser(
  [string] $email,
  [string] $password,
  [string] $name,
  [string] $phone,
  [string] $role
) {
  $existing = Get-SupabaseUser $email
  if ($null -ne $existing) {
    return $existing
  }

  $body = @{
    email = $email
    password = $password
    email_confirm = $true
    user_metadata = @{
      name = $name
      phone = $phone
      role = $role
    }
  } | ConvertTo-Json -Depth 4

  return Invoke-RestMethod `
    -Uri "$projectUrl/auth/v1/admin/users" `
    -Method Post `
    -Headers $adminHeaders `
    -ContentType 'application/json' `
    -Body $body
}

$customer = Ensure-SupabaseUser `
  'customer@gmail.com' `
  'customer123' `
  'Demo Customer' `
  '9876543210' `
  'customer'

$admin = Ensure-SupabaseUser `
  'admin@gmail.com' `
  'admin123' `
  'Main Admin' `
  '9999999999' `
  'admin'

$adminProfile = @{
  id = $admin.id
  name = 'Main Admin'
  email = 'admin@gmail.com'
  phone = '9999999999'
  role = 'admin'
} | ConvertTo-Json

$profileHeaders = $adminHeaders.Clone()
$profileHeaders['Prefer'] = 'resolution=merge-duplicates,return=minimal'
Invoke-RestMethod `
  -Uri "$projectUrl/rest/v1/admins?on_conflict=id" `
  -Method Post `
  -Headers $profileHeaders `
  -ContentType 'application/json' `
  -Body $adminProfile | Out-Null

$loginBody = @{
  email = 'customer@gmail.com'
  password = 'customer123'
} | ConvertTo-Json
$loginHeaders = @{ apikey = $publishableKey }
$session = Invoke-RestMethod `
  -Uri "$projectUrl/auth/v1/token?grant_type=password" `
  -Method Post `
  -Headers $loginHeaders `
  -ContentType 'application/json' `
  -Body $loginBody

$customerHeaders = @{
  apikey = $publishableKey
  Authorization = "Bearer $($session.access_token)"
}
Invoke-RestMethod `
  -Uri "$projectUrl/rest/v1/rpc/seed_demo_data" `
  -Method Post `
  -Headers $customerHeaders `
  -ContentType 'application/json' `
  -Body '{}' | Out-Null

Write-Output "Supabase ready: customer=$($customer.email), admin=$($admin.email)"
