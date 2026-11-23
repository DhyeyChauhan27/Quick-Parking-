import 'dart:io';

import 'package:image/image.dart' as image;

void main() {
  final roundedIcon = image.decodePng(
    File('assets/branding/quickparking_icon.png').readAsBytesSync(),
  )!;
  final foreground = image.decodePng(
    File('assets/branding/quickparking_mark.png').readAsBytesSync(),
  )!;
  final opaqueIcon = image.Image(width: 1024, height: 1024, numChannels: 4);
  image.fill(opaqueIcon, color: image.ColorRgba8(17, 24, 39, 255));
  image.compositeImage(opaqueIcon, roundedIcon);
  final android12Splash = image.Image(
    width: 1024,
    height: 1024,
    numChannels: 4,
  );
  image.compositeImage(
    android12Splash,
    roundedIcon,
    dstX: 230,
    dstY: 230,
    dstW: 564,
    dstH: 564,
  );

  const androidSizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  const splashSizes = {
    'mdpi': 128,
    'hdpi': 192,
    'xhdpi': 256,
    'xxhdpi': 384,
    'xxxhdpi': 512,
  };
  const foregroundSizes = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
  };
  for (final entry in androidSizes.entries) {
    _writeResized(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
      roundedIcon,
      entry.value,
    );
    _writeResized(
      'android/app/src/main/res/mipmap-${entry.key}/quickparking_splash.png',
      roundedIcon,
      splashSizes[entry.key]!,
    );
    _writeResized(
      'android/app/src/main/res/mipmap-${entry.key}/quickparking_splash_android12.png',
      android12Splash,
      splashSizes[entry.key]!,
    );
    _writeResized(
      'android/app/src/main/res/drawable-${entry.key}/quickparking_foreground.png',
      foreground,
      foregroundSizes[entry.key]!,
    );
  }

  _writeResized('web/favicon.png', roundedIcon, 64);
  _writeResized('web/icons/Icon-192.png', roundedIcon, 192);
  _writeResized('web/icons/Icon-512.png', roundedIcon, 512);
  _writeResized('web/icons/Icon-maskable-192.png', opaqueIcon, 192);
  _writeResized('web/icons/Icon-maskable-512.png', opaqueIcon, 512);

  const iosIcons = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  for (final entry in iosIcons.entries) {
    _writeResized(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}',
      opaqueIcon,
      entry.value,
    );
  }

  const macIcons = {
    'app_icon_16.png': 16,
    'app_icon_32.png': 32,
    'app_icon_64.png': 64,
    'app_icon_128.png': 128,
    'app_icon_256.png': 256,
    'app_icon_512.png': 512,
    'app_icon_1024.png': 1024,
  };
  for (final entry in macIcons.entries) {
    _writeResized(
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}',
      roundedIcon,
      entry.value,
    );
  }

  for (final entry in const {'': 160, '@2x': 320, '@3x': 480}.entries) {
    _writeResized(
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage${entry.key}.png',
      roundedIcon,
      entry.value,
    );
  }

  final windowsFrames = [16, 24, 32, 48, 64, 128, 256]
      .map(
        (size) => image.copyResize(
          roundedIcon,
          width: size,
          height: size,
          interpolation: image.Interpolation.linear,
        ),
      )
      .toList();
  final windowsIcon = File('windows/runner/resources/app_icon.ico');
  windowsIcon.parent.createSync(recursive: true);
  windowsIcon.writeAsBytesSync(image.IcoEncoder().encodeImages(windowsFrames));

  stdout.writeln('QuickParking branding assets generated.');
}

void _writeResized(String path, image.Image source, int size) {
  _writePng(
    path,
    image.copyResize(
      source,
      width: size,
      height: size,
      interpolation: image.Interpolation.linear,
    ),
  );
}

void _writePng(String path, image.Image source) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(image.encodePng(source));
}
