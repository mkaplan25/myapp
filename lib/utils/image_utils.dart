import 'package:image/image.dart' as img;
import 'dart:math';

// pHash hesaplama fonksiyonu
String calculatePHash(img.Image image) {
  // 1. Görüntüyü gri tonlamaya çevirin
  img.Image grayscale = img.grayscale(image);

  // 2. Görüntüyü 32x32 boyutlarına küçültün
  img.Image resized = img.copyResize(grayscale, width: 32, height: 32);

  // 3. Görüntü üzerinde Discrete Cosine Transform (DCT) uygulayın
  List<List<double>> dctMatrix = _applyDCT(resized);

  // 4. DCT matrisinin en üst 8x8 kısmını alın (low-frequency bileşenler)
  List<double> dctLowFrequency = [];
  for (int i = 0; i < 8; i++) {
    for (int j = 0; j < 8; j++) {
      dctLowFrequency.add(dctMatrix[i][j]);
    }
  }

  // 5. Ortalamanın üzerinde olan değerlere 1, diğerlerine 0 verin (binary hash oluşturun)
  double medianValue = _calculateMedian(dctLowFrequency);
  String hash = dctLowFrequency.map((e) => e > medianValue ? '1' : '0').join();

  return hash;
}

// DCT (Discrete Cosine Transform) uygulayan fonksiyon
List<List<double>> _applyDCT(img.Image image) {
  int N = image.width;
  List<List<double>> F = List.generate(N, (_) => List.filled(N, 0.0));

  for (int u = 0; u < N; u++) {
    for (int v = 0; v < N; v++) {
      double sum = 0.0;
      for (int x = 0; x < N; x++) {
        for (int y = 0; y < N; y++) {
          int pixel = image.getPixel(x, y); // `int` döner
          // RGB bileşenlerini çıkarmak için bit işlemleri kullanın
          int red = (pixel >> 16) & 0xFF;
          int green = (pixel >> 8) & 0xFF;
          int blue = pixel & 0xFF;
          // Gri tonlama değeri hesapla
          int grayValue = ((red + green + blue) ~/ 3).toInt();
          sum += grayValue *
              cos((2 * x + 1) * u * pi / (2 * N)) *
              cos((2 * y + 1) * v * pi / (2 * N));
        }
      }
      double cU = (u == 0) ? (1 / sqrt(2)) : 1.0;
      double cV = (v == 0) ? (1 / sqrt(2)) : 1.0;
      F[u][v] = 0.25 * cU * cV * sum;
    }
  }

  return F;
}

// Median değeri hesaplayan fonksiyon
double _calculateMedian(List<double> values) {
  List<double> sortedValues = List.from(values)..sort();
  int middle = sortedValues.length ~/ 2;
  if (sortedValues.length % 2 == 1) {
    return sortedValues[middle];
  } else {
    return (sortedValues[middle - 1] + sortedValues[middle]) / 2.0;
  }
}
