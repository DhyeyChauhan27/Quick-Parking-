param(
  [string]$OutputPath = (Join-Path $PSScriptRoot '..\docs\diagrams\quickparking_customer_admin_dfd.drawio')
)

$ErrorActionPreference = 'Stop'
$cells = [System.Collections.Generic.List[string]]::new()

function Escape-Xml([string]$Value) {
  return [System.Security.SecurityElement]::Escape($Value)
}

function Add-Vertex {
  param(
    [string]$Id,
    [string]$Value,
    [string]$Style,
    [double]$X,
    [double]$Y,
    [double]$Width,
    [double]$Height
  )

  $escapedValue = Escape-Xml $Value
  $cells.Add("    <mxCell id=`"$Id`" value=`"$escapedValue`" style=`"$Style`" vertex=`"1`" parent=`"1`"><mxGeometry x=`"$X`" y=`"$Y`" width=`"$Width`" height=`"$Height`" as=`"geometry`"/></mxCell>")
}

function Add-Edge {
  param(
    [string]$Id,
    [string]$Value,
    [string]$Source,
    [string]$Target,
    [string]$Style
  )

  $escapedValue = Escape-Xml $Value
  $cells.Add("    <mxCell id=`"$Id`" value=`"$escapedValue`" style=`"$Style`" edge=`"1`" parent=`"1`" source=`"$Source`" target=`"$Target`"><mxGeometry relative=`"1`" as=`"geometry`"/></mxCell>")
}

$panelStyle = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#000000;strokeColor=#FFFFFF;strokeWidth=3;arcSize=2;pointerEvents=0;'
$lineStyle = 'rounded=0;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=none;pointerEvents=0;'
$titleStyle = 'text;html=1;align=center;verticalAlign=middle;resizable=0;points=[];autosize=0;strokeColor=none;fillColor=none;fontColor=#FFFFFF;fontSize=30;fontStyle=1;pointerEvents=0;'
$actorStyle = 'rounded=1;whiteSpace=wrap;html=1;fillColor=#000000;strokeColor=#FFFFFF;strokeWidth=3;fontColor=#FFFFFF;fontSize=22;fontStyle=1;align=center;verticalAlign=middle;arcSize=7;'
$processStyle = 'ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor=#000000;strokeColor=#FFFFFF;strokeWidth=3;fontColor=#FFFFFF;fontSize=17;fontStyle=1;align=center;verticalAlign=middle;'
$storeStyle = 'shape=partialRectangle;top=1;left=1;bottom=1;right=0;whiteSpace=wrap;html=1;fillColor=#000000;strokeColor=#FFFFFF;strokeWidth=3;fontColor=#FFFFFF;fontSize=16;fontStyle=1;align=center;verticalAlign=middle;spacingLeft=12;'
$storeBarStyle = 'rounded=0;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=none;pointerEvents=0;'
$footerStyle = 'text;html=1;align=center;verticalAlign=middle;resizable=0;points=[];autosize=0;strokeColor=none;fillColor=none;fontColor=#BFC7D5;fontSize=13;pointerEvents=0;'
$edgeBase = 'edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#FFFFFF;strokeWidth=2;endArrow=block;endFill=1;fontColor=#FFFFFF;fontSize=13;labelBackgroundColor=#000000;'

Add-Vertex 'customer-panel' '' $panelStyle 10 10 1175 1380
Add-Vertex 'customer-title-line' '' $lineStyle 10 78 1175 2
Add-Vertex 'customer-title' 'QuickParking - Customer DFD (Level 0)' $titleStyle 160 18 875 50
Add-Vertex 'customer-actor' 'CUSTOMER' $actorStyle 30 160 155 1130
Add-Vertex 'customer-footer' 'Flutter + Supabase Authentication, PostgreSQL, Realtime, Storage, RLS and RPC' $footerStyle 190 1340 815 28

Add-Vertex 'admin-panel' '' $panelStyle 1215 10 1175 1380
Add-Vertex 'admin-title-line' '' $lineStyle 1215 78 1175 2
Add-Vertex 'admin-title' 'QuickParking - Admin DFD (Level 0)' $titleStyle 1365 18 875 50
Add-Vertex 'admin-actor' 'ADMIN' $actorStyle 1235 145 155 1160
Add-Vertex 'admin-footer' 'Role checks and Row Level Security protect all administrator operations' $footerStyle 1395 1340 815 28

$customerRows = @(
  @{ Id='c1'; Y=150; StoreY=166; Number='1.0'; Process='Login / Register<br>/ Reset / Logout'; Store='Auth + Users<br>(Supabase)'; Request='Credentials / registration data'; Response='Auth or recovery status'; Write='Auth request / user data'; Read='Session / profile data' },
  @{ Id='c2'; Y=295; StoreY=311; Number='2.0'; Process='Search Parking'; Store='Parking Locations<br>(Supabase)'; Request='Search / filter request'; Response='Matching locations'; Write='Location query'; Read='Location details' },
  @{ Id='c3'; Y=440; StoreY=456; Number='3.0'; Process='View Location<br>Details &amp; Slots'; Store='Parking Slots<br>(Supabase)'; Request='Selected location'; Response='Available slot list'; Write='Slot query'; Read='Live slot status' },
  @{ Id='c4'; Y=585; StoreY=601; Number='4.0'; Process='Book Parking'; Store='Bookings<br>(Supabase)'; Request='Date, slot, vehicle'; Response='Booking confirmation'; Write='Atomic booking request'; Read='Booking code / status' },
  @{ Id='c5'; Y=730; StoreY=746; Number='5.0'; Process='Make Payment'; Store='Payments<br>(Supabase)'; Request='Payment method'; Response='Payment result'; Write='Payment transaction'; Read='Paid status' },
  @{ Id='c6'; Y=875; StoreY=891; Number='6.0'; Process='View / Cancel<br>Booking'; Store='Bookings + Slots<br>(Supabase)'; Request='History / cancel request'; Response='List / cancellation result'; Write='Read / cancel booking'; Read='Updated booking status' },
  @{ Id='c7'; Y=1020; StoreY=1036; Number='7.0'; Process='View QR Pass<br>/ Download Invoice'; Store='Bookings + Payments<br>(Supabase)'; Request='QR / invoice request'; Response='QR pass / PDF invoice'; Write='Booking / payment query'; Read='QR and receipt data' },
  @{ Id='c8'; Y=1165; StoreY=1181; Number='8.0'; Process='Profile &amp; Alerts'; Store='Users + Notifications<br>(Supabase)'; Request='Profile / alerts request'; Response='Profile / notifications'; Write='Profile update / alerts query'; Read='Updated user / alert data' }
)

for ($index = 0; $index -lt $customerRows.Count; $index++) {
  $row = $customerRows[$index]
  $processId = "$($row.Id)-process"
  $storeId = "$($row.Id)-store"
  Add-Vertex $processId "<b>$($row.Number)</b><br>$($row.Process)" $processStyle 395 $row.Y 290 110
  Add-Vertex $storeId $row.Store $storeStyle 940 $row.StoreY 220 78
  Add-Vertex "$($row.Id)-store-bar" '' $storeBarStyle 950 $row.StoreY 2 78

  $actorExit = [math]::Round((($row.Y + 55) - 160) / 1130, 4)
  Add-Edge "$($row.Id)-request" $row.Request 'customer-actor' $processId ($edgeBase + "exitX=1;exitY=$actorExit;entryX=0;entryY=0.36;")
  Add-Edge "$($row.Id)-response" $row.Response $processId 'customer-actor' ($edgeBase + "exitX=0;exitY=0.64;entryX=1;entryY=$actorExit;")
  Add-Edge "$($row.Id)-write" $row.Write $processId $storeId ($edgeBase + 'exitX=1;exitY=0.36;entryX=0;entryY=0.36;')
  Add-Edge "$($row.Id)-read" $row.Read $storeId $processId ($edgeBase + 'exitX=0;exitY=0.64;entryX=1;entryY=0.64;')
}

$adminRows = @(
  @{ Id='a1'; Y=125; StoreY=139; Number='1.0'; Process='Login / Logout'; Store='Auth + Admins<br>(Supabase)'; Request='Admin credentials'; Response='Authentication status'; Write='Role verification request'; Read='Admin session / profile' },
  @{ Id='a2'; Y=260; StoreY=274; Number='2.0'; Process='Manage Locations'; Store='Locations + Storage<br>(Supabase)'; Request='Add / update / delete'; Response='Location details'; Write='Location / image data'; Read='Updated location data' },
  @{ Id='a3'; Y=395; StoreY=409; Number='3.0'; Process='Manage Slots'; Store='Parking Slots<br>(Supabase)'; Request='Add / update / delete'; Response='Slot details'; Write='Slot data'; Read='Updated slot status' },
  @{ Id='a4'; Y=530; StoreY=544; Number='4.0'; Process='Manage Bookings'; Store='Bookings<br>(Supabase)'; Request='View / update booking'; Response='Booking details'; Write='Booking query / update'; Read='Booking status' },
  @{ Id='a5'; Y=665; StoreY=679; Number='5.0'; Process='Manage Payments'; Store='Payments<br>(Supabase)'; Request='View transactions'; Response='Payment details'; Write='Payment query'; Read='Transaction records' },
  @{ Id='a6'; Y=800; StoreY=814; Number='6.0'; Process='Manage Customers'; Store='Users<br>(Supabase)'; Request='View / delete customer'; Response='Customer details'; Write='User query / delete'; Read='Updated user data' },
  @{ Id='a7'; Y=935; StoreY=949; Number='7.0'; Process='Verify Entry / Exit'; Store='Bookings + Slots<br>(Supabase RPC)'; Request='QR payload / booking code'; Response='Entry / exit result'; Write='Atomic verification request'; Read='Booking / slot status' },
  @{ Id='a8'; Y=1070; StoreY=1084; Number='8.0'; Process='Reports &amp; Analytics'; Store='Bookings + Payments<br>(Supabase)'; Request='Daily / monthly / yearly'; Response='Summary / PDF / XML'; Write='Report data query'; Read='Bookings / revenue data' },
  @{ Id='a9'; Y=1205; StoreY=1219; Number='9.0'; Process='Appearance Settings'; Store='Local Preferences<br>(Device)'; Request='Select light / dark mode'; Response='Applied appearance'; Write='Save preference'; Read='Stored theme mode' }
)

for ($index = 0; $index -lt $adminRows.Count; $index++) {
  $row = $adminRows[$index]
  $processId = "$($row.Id)-process"
  $storeId = "$($row.Id)-store"
  Add-Vertex $processId "<b>$($row.Number)</b><br>$($row.Process)" $processStyle 1600 $row.Y 290 100
  Add-Vertex $storeId $row.Store $storeStyle 2145 $row.StoreY 220 72
  Add-Vertex "$($row.Id)-store-bar" '' $storeBarStyle 2155 $row.StoreY 2 72

  $actorExit = [math]::Round((($row.Y + 50) - 145) / 1160, 4)
  Add-Edge "$($row.Id)-request" $row.Request 'admin-actor' $processId ($edgeBase + "exitX=1;exitY=$actorExit;entryX=0;entryY=0.36;")
  Add-Edge "$($row.Id)-response" $row.Response $processId 'admin-actor' ($edgeBase + "exitX=0;exitY=0.64;entryX=1;entryY=$actorExit;")
  Add-Edge "$($row.Id)-write" $row.Write $processId $storeId ($edgeBase + 'exitX=1;exitY=0.36;entryX=0;entryY=0.36;')
  Add-Edge "$($row.Id)-read" $row.Read $storeId $processId ($edgeBase + 'exitX=0;exitY=0.64;entryX=1;entryY=0.64;')
}

$xml = @"
<mxfile host="app.diagrams.net" modified="2026-09-30T00:00:00.000Z" agent="OpenAI Codex" version="26.0.16" type="device" compressed="false">
  <diagram id="quickparking-dfd" name="Customer and Admin DFD">
    <mxGraphModel dx="2400" dy="1400" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="2400" pageHeight="1400" background="#000000" math="0" shadow="0">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
$($cells -join "`n")
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
"@

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($resolvedOutput)) | Out-Null
[System.IO.File]::WriteAllText($resolvedOutput, $xml, [System.Text.UTF8Encoding]::new($false))
Write-Output $resolvedOutput
