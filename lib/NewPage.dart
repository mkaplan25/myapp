import 'package:flutter/material.dart';
import 'package:myapp/screenshot_manager.dart';
import 'benzer.dart';
import 'live.dart';

class NewPage extends StatelessWidget {
  final String title;

  const NewPage({super.key, required this.title});

  void _navigateToCategory1(BuildContext context, String category) {
    // Her bir kategoriye tıkladığınızda yönlendirme yapılacak sayfa
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BenzerSayfa(),
      ),
    );
  }
  void _navigateToCategory2(BuildContext context, String category) {
    // Her bir kategoriye tıkladığınızda yönlendirme yapılacak sayfa
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScreenshotManager(),
      ),
    );
  }
  void _navigateToCategory3(BuildContext context, String category) {
    // Her bir kategoriye tıkladığınızda yönlendirme yapılacak sayfa
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LivePhotoManager(),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 3 tıklanabilir alan
            GestureDetector(
              onTap: () => _navigateToCategory1(context, 'Benzer Fotoğraflar'),
              child: const CategoryItem(title: 'Benzer Fotoğraflar'),
            ),
            const SizedBox(height: 20), // Aralığı belirlemek için
            GestureDetector(
              onTap: () => _navigateToCategory2(context, 'Ekran Görüntüleri'),
              child: const CategoryItem(title: 'Ekran Görüntüleri'),
            ),
            const SizedBox(height: 20), // Aralığı belirlemek için
            GestureDetector(
              onTap: () => _navigateToCategory3(context, 'Live Photos'),
              child: const CategoryItem(title: 'Live Photos'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(ScreenshotApp());
}

class ScreenshotApp extends StatelessWidget {
  const ScreenshotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screenshot Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ScreenshotManager(),
    );
  }
}

class CategoryItem extends StatelessWidget {
  final String title;

  const CategoryItem({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}


