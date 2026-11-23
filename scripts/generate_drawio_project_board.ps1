param(
  [string]$OutputPath = (Join-Path $PSScriptRoot '..\docs\diagrams\quickparking_complete_project_diagrams.drawio')
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
  $valueXml = Escape-Xml $Value
  $cells.Add("        <mxCell id=`"$Id`" value=`"$valueXml`" style=`"$Style`" vertex=`"1`" parent=`"1`"><mxGeometry x=`"$X`" y=`"$Y`" width=`"$Width`" height=`"$Height`" as=`"geometry`"/></mxCell>")
}

function Add-Edge {
  param(
    [string]$Id,
    [string]$Value,
    [string]$Source,
    [string]$Target,
    [string]$Style
  )
  $valueXml = Escape-Xml $Value
  $cells.Add("        <mxCell id=`"$Id`" value=`"$valueXml`" style=`"$Style`" edge=`"1`" parent=`"1`" source=`"$Source`" target=`"$Target`"><mxGeometry relative=`"1`" as=`"geometry`"/></mxCell>")
}

function Add-DfdRow {
  param(
    [string]$Prefix,
    [string]$ActorId,
    [double]$ActorTop,
    [double]$ActorHeight,
    [double]$ProcessX,
    [double]$ProcessY,
    [double]$StoreX,
    [string]$Number,
    [string]$Process,
    [string]$Store,
    [string]$Request,
    [string]$Response,
    [string]$Write,
    [string]$Read
  )
  $processId = "$Prefix-process"
  $storeId = "$Prefix-store"
  Add-Vertex $processId "<b>$Number</b><br>$Process" $script:processStyle $ProcessX $ProcessY 300 90
  Add-Vertex $storeId $Store $script:storeStyle $StoreX ($ProcessY + 8) 260 74
  $exitY = [Math]::Round((($ProcessY + 45) - $ActorTop) / $ActorHeight, 4)
  Add-Edge "$Prefix-request" $Request $ActorId $processId ($script:dfdEdge + "exitX=1;exitY=$exitY;entryX=0;entryY=0.33;")
  Add-Edge "$Prefix-response" $Response $processId $ActorId ($script:dfdEdge + "exitX=0;exitY=0.67;entryX=1;entryY=$exitY;")
  Add-Edge "$Prefix-write" $Write $processId $storeId ($script:dfdEdge + 'exitX=1;exitY=0.33;entryX=0;entryY=0.33;')
  Add-Edge "$Prefix-read" $Read $storeId $processId ($script:dfdEdge + 'exitX=0;exitY=0.67;entryX=1;entryY=0.67;')
}

function Add-Entity {
  param(
    [string]$Id,
    [string]$Name,
    [double]$X,
    [double]$Y,
    [array]$Attributes
  )
  Add-Vertex $Id $Name $script:entityStyle $X $Y 210 74
  $index = 0
  foreach ($attribute in $Attributes) {
    $attributeId = "$Id-attribute-$index"
    Add-Vertex $attributeId $attribute.Name $script:attributeStyle $attribute.X $attribute.Y $attribute.W 54
    Add-Edge "$attributeId-edge" '' $attributeId $Id $script:erEdge
    $index++
  }
}

function Add-Relationship {
  param(
    [string]$Id,
    [string]$Name,
    [double]$X,
    [double]$Y,
    [string]$LeftEntity,
    [string]$RightEntity,
    [string]$LeftCardinality = '1',
    [string]$RightCardinality = 'N'
  )
  Add-Vertex $Id $Name $script:relationshipStyle $X $Y 150 90
  Add-Edge "$Id-left" $LeftCardinality $LeftEntity $Id $script:erEdge
  Add-Edge "$Id-right" $RightCardinality $Id $RightEntity $script:erEdge
}

$sectionTitleStyle = 'text;html=1;align=center;verticalAlign=middle;strokeColor=none;fillColor=none;fontColor=#111111;fontSize=23;fontStyle=1;'
$boardTitleStyle = 'text;html=1;align=center;verticalAlign=middle;strokeColor=none;fillColor=none;fontColor=#111111;fontSize=34;fontStyle=1;'
$noteStyle = 'text;html=1;align=center;verticalAlign=middle;strokeColor=none;fillColor=none;fontColor=#555555;fontSize=13;fontStyle=2;'
$externalStyle = 'rounded=0;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#222222;strokeWidth=2;fontColor=#111111;fontSize=17;fontStyle=1;align=center;verticalAlign=middle;'
$processStyle = 'ellipse;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#222222;strokeWidth=2;fontColor=#111111;fontSize=15;align=center;verticalAlign=middle;'
$storeStyle = 'shape=partialRectangle;top=1;left=1;bottom=1;right=0;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#222222;strokeWidth=2;fontColor=#111111;fontSize=15;align=center;verticalAlign=middle;spacingLeft=12;'
$dfdEdge = 'edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#222222;strokeWidth=1.7;endArrow=classic;endFill=1;fontColor=#111111;fontSize=12;labelBackgroundColor=#FFFFFF;'
$boundaryStyle = 'rounded=0;whiteSpace=wrap;html=1;fillColor=none;strokeColor=#333333;strokeWidth=2;'
$actorStyle = 'shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;html=1;fillColor=#FFFFFF;strokeColor=#222222;strokeWidth=2;fontColor=#111111;fontSize=15;fontStyle=1;'
$useCaseStyle = 'ellipse;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#222222;strokeWidth=1.7;fontColor=#111111;fontSize=14;align=center;verticalAlign=middle;'
$associationStyle = 'edgeStyle=none;html=1;strokeColor=#333333;strokeWidth=1.5;endArrow=none;startArrow=none;'
$entityStyle = 'rounded=0;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#222222;strokeWidth=2;fontColor=#111111;fontSize=16;fontStyle=1;align=center;verticalAlign=middle;'
$attributeStyle = 'ellipse;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#555555;strokeWidth=1.5;fontColor=#111111;fontSize=12;align=center;verticalAlign=middle;'
$relationshipStyle = 'rhombus;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#222222;strokeWidth=1.8;fontColor=#111111;fontSize=12;fontStyle=1;align=center;verticalAlign=middle;'
$erEdge = 'edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#333333;strokeWidth=1.5;endArrow=none;startArrow=none;fontColor=#111111;fontSize=12;labelBackgroundColor=#FFFFFF;'

Add-Vertex 'board-title' 'QUICKPARKING SYSTEM DIAGRAMS' $boardTitleStyle 1500 20 2000 60

# DFD LEVEL 0 / CONTEXT
Add-Vertex 'context-title' 'DFD DIAGRAM<br>LEVEL - 0' $sectionTitleStyle 620 105 420 70
Add-Vertex 'context-customer' 'CUSTOMER' $externalStyle 160 310 250 95
Add-Vertex 'context-admin' 'ADMIN' $externalStyle 160 500 250 95
Add-Vertex 'context-system' '<b>0.0</b><br>QuickParking<br>System' $processStyle 720 335 310 210
Add-Vertex 'context-store' 'SUPABASE DATABASE<br>Auth | PostgreSQL | Storage' $storeStyle 1320 385 390 110
Add-Edge 'context-customer-request' 'Registration, search, booking and payment requests' 'context-customer' 'context-system' $dfdEdge
Add-Edge 'context-customer-response' 'Availability, confirmation, QR, invoice and alerts' 'context-system' 'context-customer' $dfdEdge
Add-Edge 'context-admin-request' 'Management, verification and report requests' 'context-admin' 'context-system' $dfdEdge
Add-Edge 'context-admin-response' 'Dashboard, records and report results' 'context-system' 'context-admin' $dfdEdge
Add-Edge 'context-db-write' 'Secure queries and commands' 'context-system' 'context-store' $dfdEdge
Add-Edge 'context-db-read' 'Authentication, data and realtime updates' 'context-store' 'context-system' $dfdEdge

# ADMIN DFD LEVEL 1
Add-Vertex 'admin-dfd-title' 'ADMIN DFD DIAGRAM - LEVEL 1' $sectionTitleStyle 300 730 1100 60
Add-Vertex 'admin-dfd-actor' 'ADMIN' $externalStyle 180 880 230 940
$adminRows = @(
  @{Prefix='admin-1';Y=830;No='1.0';Process='Login / Logout';Store='Auth + Admins';Request='Credentials';Response='Authentication status';Write='Role verification';Read='Admin session'},
  @{Prefix='admin-2';Y=970;No='2.0';Process='Manage Locations';Store='Parking Locations + Storage';Request='Add / update / delete';Response='Location details';Write='Location and image data';Read='Updated location'},
  @{Prefix='admin-3';Y=1110;No='3.0';Process='Manage Slots';Store='Parking Slots';Request='Add / update / delete';Response='Slot details';Write='Slot data';Read='Updated slot status'},
  @{Prefix='admin-4';Y=1250;No='4.0';Process='Manage Bookings<br>&amp; Payments';Store='Bookings + Payments';Request='View / update records';Response='Booking / payment details';Write='Record query / update';Read='Updated status'},
  @{Prefix='admin-5';Y=1390;No='5.0';Process='Manage Customers';Store='Users';Request='View / delete customer';Response='Customer details';Write='User query / delete';Read='Updated users'},
  @{Prefix='admin-6';Y=1530;No='6.0';Process='Verify Entry / Exit';Store='Bookings + Slots RPC';Request='QR / booking code';Response='Verification result';Write='Atomic verification';Read='Booking / slot status'},
  @{Prefix='admin-7';Y=1670;No='7.0';Process='Reports &amp; Analytics';Store='Bookings + Payments';Request='Daily / monthly / yearly';Response='PDF / XML report';Write='Report query';Read='Revenue and booking data'}
)
foreach ($row in $adminRows) {
  Add-DfdRow $row.Prefix 'admin-dfd-actor' 880 940 590 $row.Y 1200 $row.No $row.Process $row.Store $row.Request $row.Response $row.Write $row.Read
}

# CUSTOMER DFD LEVEL 1
Add-Vertex 'customer-dfd-title' 'CUSTOMER DFD DIAGRAM - LEVEL 1' $sectionTitleStyle 1900 730 1100 60
Add-Vertex 'customer-dfd-actor' 'CUSTOMER' $externalStyle 1780 880 230 940
$customerRows = @(
  @{Prefix='customer-1';Y=830;No='1.0';Process='Login / Register<br>/ Reset';Store='Auth + Users';Request='Account data';Response='Authentication status';Write='Auth / profile request';Read='Session / profile'},
  @{Prefix='customer-2';Y=970;No='2.0';Process='Search Parking';Store='Parking Locations';Request='Search / filter';Response='Matching locations';Write='Location query';Read='Location data'},
  @{Prefix='customer-3';Y=1110;No='3.0';Process='View Details<br>&amp; Slots';Store='Parking Slots';Request='Selected location';Response='Available slots';Write='Slot query';Read='Live slot status'},
  @{Prefix='customer-4';Y=1250;No='4.0';Process='Book Parking';Store='Bookings + Slots RPC';Request='Date, slot, vehicle';Response='Booking confirmation';Write='Atomic booking';Read='Code and status'},
  @{Prefix='customer-5';Y=1390;No='5.0';Process='Make Payment';Store='Payments + Bookings';Request='Payment method';Response='Payment result';Write='Payment transaction';Read='Paid status'},
  @{Prefix='customer-6';Y=1530;No='6.0';Process='History / QR<br>/ Invoice';Store='Bookings + Payments';Request='History / receipt request';Response='List, QR and PDF';Write='Booking query';Read='Booking / receipt data'},
  @{Prefix='customer-7';Y=1670;No='7.0';Process='Profile &amp; Alerts';Store='Users + Notifications';Request='Profile / alerts request';Response='Profile / notifications';Write='Update / alerts query';Read='Updated profile / alerts'}
)
foreach ($row in $customerRows) {
  Add-DfdRow $row.Prefix 'customer-dfd-actor' 880 940 2190 $row.Y 2800 $row.No $row.Process $row.Store $row.Request $row.Response $row.Write $row.Read
}

# USE CASE DIAGRAM
Add-Vertex 'use-case-title' 'USE CASE DIAGRAM' $sectionTitleStyle 3740 640 850 60
Add-Vertex 'use-case-boundary' '' $boundaryStyle 3720 760 900 1110
Add-Vertex 'use-case-system-name' 'QuickParking System' $noteStyle 3970 1815 400 35
Add-Vertex 'use-case-admin-actor' 'ADMIN' $actorStyle 3510 1120 120 210
Add-Vertex 'use-case-customer-actor' 'CUSTOMER' $actorStyle 4690 1120 120 210
$useCases = @(
  @{Id='uc-auth';Y=815;Text='Register / Login<br>/ Reset Password'},
  @{Id='uc-search';Y=935;Text='Search Parking<br>&amp; View Slots'},
  @{Id='uc-book';Y=1055;Text='Book Parking'},
  @{Id='uc-pay';Y=1175;Text='Make Payment'},
  @{Id='uc-pass';Y=1295;Text='QR Pass / Invoice<br>/ Booking History'},
  @{Id='uc-manage';Y=1415;Text='Manage Customers,<br>Locations &amp; Slots'},
  @{Id='uc-verify';Y=1535;Text='Manage Bookings / Payments<br>&amp; Verify Entry / Exit'},
  @{Id='uc-report';Y=1655;Text='Reports, Analytics<br>&amp; Settings'}
)
foreach ($useCase in $useCases) {
  Add-Vertex $useCase.Id $useCase.Text $useCaseStyle 3990 $useCase.Y 360 86
}
foreach ($id in @('uc-auth','uc-manage','uc-verify','uc-report')) {
  Add-Edge "admin-$id" '' 'use-case-admin-actor' $id $associationStyle
}
foreach ($id in @('uc-auth','uc-search','uc-book','uc-pay','uc-pass')) {
  Add-Edge "customer-$id" '' 'use-case-customer-actor' $id $associationStyle
}

# CLASSIC CHEN E.R. DIAGRAM
Add-Vertex 'er-title' 'E.R. DIAGRAM' $sectionTitleStyle 1950 1990 1000 65
Add-Vertex 'er-note' 'Core Supabase entities and attributes (PK = primary key, FK = foreign key)' $noteStyle 1550 2050 1800 40

Add-Entity 'entity-admin' 'ADMINS' 240 2490 @(
  @{Name='id (PK/FK)';X=70;Y=2370;W=150}, @{Name='name';X=255;Y=2310;W=130}, @{Name='email';X=420;Y=2370;W=150}, @{Name='phone';X=55;Y=2615;W=150}, @{Name='role';X=310;Y=2675;W=120}
)
Add-Entity 'entity-user' 'USERS' 930 2490 @(
  @{Name='id (PK/FK)';X=760;Y=2370;W=150}, @{Name='name';X=945;Y=2310;W=130}, @{Name='email';X=1110;Y=2370;W=150}, @{Name='phone';X=745;Y=2615;W=150}, @{Name='role';X=1000;Y=2675;W=120}
)
Add-Entity 'entity-location' 'PARKING_LOCATIONS' 1660 2490 @(
  @{Name='id (PK)';X=1500;Y=2350;W=130}, @{Name='name';X=1660;Y=2290;W=140}, @{Name='address';X=1840;Y=2325;W=150}, @{Name='city';X=1480;Y=2630;W=120}, @{Name='base_rate';X=1640;Y=2690;W=150}, @{Name='available_slots';X=1830;Y=2635;W=180}
)
Add-Entity 'entity-slot' 'PARKING_SLOTS' 2420 2490 @(
  @{Name='id (PK)';X=2260;Y=2350;W=130}, @{Name='location_id (FK)';X=2405;Y=2285;W=180}, @{Name='slot_number';X=2620;Y=2340;W=160}, @{Name='floor';X=2240;Y=2630;W=120}, @{Name='status';X=2410;Y=2690;W=130}, @{Name='rate_per_hour';X=2580;Y=2630;W=180}
)
Add-Entity 'entity-booking' 'BOOKINGS' 3260 2490 @(
  @{Name='id (PK)';X=3060;Y=2310;W=130}, @{Name='booking_code';X=3220;Y=2245;W=170}, @{Name='user_id (FK)';X=3420;Y=2295;W=160}, @{Name='location_id (FK)';X=3000;Y=2410;W=180}, @{Name='slot_id (FK)';X=3480;Y=2410;W=150}, @{Name='start / end time';X=3010;Y=2660;W=190}, @{Name='status';X=3240;Y=2720;W=130}, @{Name='amount / payment';X=3430;Y=2660;W=190}
)
Add-Entity 'entity-payment' 'PAYMENTS' 4230 2490 @(
  @{Name='id (PK)';X=4060;Y=2350;W=130}, @{Name='booking_id (FK)';X=4210;Y=2285;W=180}, @{Name='user_id (FK)';X=4420;Y=2350;W=160}, @{Name='amount';X=4030;Y=2630;W=140}, @{Name='method';X=4210;Y=2690;W=140}, @{Name='status / paid_at';X=4400;Y=2630;W=180}
)
Add-Entity 'entity-notification' 'NOTIFICATIONS' 1510 3190 @(
  @{Name='id (PK)';X=1340;Y=3060;W=130}, @{Name='user_id (FK)';X=1490;Y=3000;W=160}, @{Name='title / message';X=1680;Y=3060;W=180}, @{Name='type';X=1330;Y=3320;W=120}, @{Name='read';X=1510;Y=3370;W=120}, @{Name='created_at';X=1680;Y=3320;W=150}
)
Add-Entity 'entity-complaint' 'COMPLAINTS' 2600 3190 @(
  @{Name='id (PK)';X=2430;Y=3060;W=130}, @{Name='user_id (FK)';X=2580;Y=3000;W=160}, @{Name='subject / message';X=2770;Y=3060;W=190}, @{Name='status';X=2490;Y=3335;W=130}, @{Name='created_at';X=2710;Y=3335;W=150}
)

Add-Relationship 'relationship-manages' 'MANAGES' 1100 2135 'entity-admin' 'entity-location' '1' 'N'
Add-Relationship 'relationship-contains' 'CONTAINS' 2110 2480 'entity-location' 'entity-slot' '1' 'N'
Add-Relationship 'relationship-reserves' 'RESERVES' 2880 2480 'entity-slot' 'entity-booking' '1' 'N'
Add-Relationship 'relationship-has-payment' 'HAS' 3880 2480 'entity-booking' 'entity-payment' '1' '0..1'
Add-Relationship 'relationship-makes' 'MAKES' 2860 2850 'entity-user' 'entity-booking' '1' 'N'
Add-Relationship 'relationship-receives' 'RECEIVES' 1220 3030 'entity-user' 'entity-notification' '1' 'N'
Add-Relationship 'relationship-submits' 'SUBMITS' 2180 3190 'entity-user' 'entity-complaint' '1' 'N'

$xml = @"
<mxfile host="app.diagrams.net" modified="2026-10-06T00:00:00.000Z" agent="OpenAI Codex" version="26.0.16" type="device" compressed="false">
  <diagram id="quickparking-complete-board" name="QuickParking Complete Diagrams">
    <mxGraphModel dx="5000" dy="3600" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="5000" pageHeight="3600" background="#FFFFFF" math="0" shadow="0">
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
