import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'NewPage.dart';
import 'video.dart';

void main() {
  runApp(CleanerApp());
}

class CleanerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cleaner App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  double totalStorage = 0.0;
  double freeStorage = 0.0;
  int totalPhotoCount = 0;
  int totalPhotoSize = 0;
  int totalVideoCount = 0;
  int totalVideoSize = 0;
  int totalContacts = 0;
  late AnimationController _controller;
  static const platform = MethodChannel('storageInfo');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..forward();
    _fetchStorageInfo();
    _fetchMediaInfo();
    _fetchContactsInfo();
  }

  Future<void> _fetchStorageInfo() async {
    try {
      final storageInfo = await platform.invokeMethod('getStorageInfo');
      setState(() {
        totalStorage =
            (storageInfo['totalStorage'] as int) / (1024 * 1024 * 1024);
        freeStorage =
            (storageInfo['freeStorage'] as int) / (1024 * 1024 * 1024);
      });
    } on PlatformException catch (e) {
      print("Failed to get storage info: ${e.message}");
    }
  }

  Future<void> _fetchMediaInfo() async {
    final PermissionState permission =
        await PhotoManager.requestPermissionExtend();
    if (permission.isAuth == false) {
      return;
    }

    final List<AssetPathEntity> albums =
        await PhotoManager.getAssetPathList(type: RequestType.all);

    if (albums.isNotEmpty) {
      int photoCount = 0;
      int photoSize = 0;
      int videoCount = 0;
      int videoSize = 0;

      for (var album in albums) {
        final List<AssetEntity> media =
            await album.getAssetListPaged(page: 0, size: 100);
        for (var item in media) {
          final file = await item.originFile;
          if (item.type == AssetType.image) {
            photoCount++;
            photoSize += file?.lengthSync() ?? 0;
          } else if (item.type == AssetType.video) {
            videoCount++;
            videoSize += file?.lengthSync() ?? 0;
          }
        }
      }

      setState(() {
        totalPhotoCount = photoCount;
        totalPhotoSize = photoSize;
        totalVideoCount = videoCount;
        totalVideoSize = videoSize;
      });
    }
  }

  Future<void> _fetchContactsInfo() async {
    try {
      Iterable<Contact> contacts = await ContactsService.getContacts();
      setState(() {
        totalContacts = contacts.length;
      });
    } catch (e) {
      print("Failed to get contacts: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double usedStorage = totalStorage - freeStorage;
    double usagePercentage = (usedStorage / totalStorage).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Cleaner App'),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: Icon(Icons.star, color: Colors.yellow),
            label: Text(
              'Premium',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      "Storage Usage",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    StorageUsageBar(
                      controller: _controller,
                      usagePercentage: usagePercentage,
                      totalStorage: totalStorage,
                      usedStorage: usedStorage,
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => NewPage(title: 'Photos')),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    FutureBuilder<List<AssetEntity>>(
                      future: PhotoManager.getAssetPathList(
                              type: RequestType.image)
                          .then((albums) =>
                              albums.first.getAssetListPaged(page: 0, size: 3)),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: snapshot.data!
                                .map((media) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: FutureBuilder<Uint8List?>(
                                          future: media.thumbnailData,
                                          builder: (context, thumbSnapshot) {
                                            if (thumbSnapshot.connectionState ==
                                                    ConnectionState.done &&
                                                thumbSnapshot.hasData) {
                                              return Image.memory(
                                                  thumbSnapshot.data!,
                                                  width: 100,
                                                  height: 100,
                                                  fit: BoxFit.cover);
                                            } else {
                                              return CircularProgressIndicator();
                                            }
                                          },
                                        ),
                                      ),
                                    ))
                                .toList(),
                          );
                        } else {
                          return CircularProgressIndicator();
                        }
                      },
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "${totalPhotoCount} photos",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "${_formatBytes(totalPhotoSize, 2)}",
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VideoManagerPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    FutureBuilder<List<AssetEntity>>(
                      future: PhotoManager.getAssetPathList(
                              type: RequestType.video)
                          .then((albums) =>
                              albums.first.getAssetListPaged(page: 0, size: 3)),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: snapshot.data!
                                .map((video) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: FutureBuilder<Uint8List?>(
                                          future: video.thumbnailData,
                                          builder: (context, thumbSnapshot) {
                                            if (thumbSnapshot.connectionState ==
                                                    ConnectionState.done &&
                                                thumbSnapshot.hasData) {
                                              return Image.memory(
                                                  thumbSnapshot.data!,
                                                  width: 100,
                                                  height: 100,
                                                  fit: BoxFit.cover);
                                            } else {
                                              return CircularProgressIndicator();
                                            }
                                          },
                                        ),
                                      ),
                                    ))
                                .toList(),
                          );
                        } else {
                          return CircularProgressIndicator();
                        }
                      },
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(
                      "Video Organized",
                      style: TextStyle(fontSize: 20),
                    ),
                            Text(
                              "${totalVideoCount} videos",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "${_formatBytes(totalVideoSize, 2)}",
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Contacts",
                      style: TextStyle(fontSize: 20),
                    ),
                    Text(
                      "$totalContacts",
                      style: TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black87,
        selectedItemColor: Colors.yellow,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.photo_library), label: 'Swipe Photos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.build), label: 'Extra Tools'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: 0,
        onTap: (index) {},
      ),
    );
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes == 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) +
        " " +
        suffixes[i];
  }
}

class StorageUsageBar extends StatelessWidget {
  final AnimationController controller;
  final double usagePercentage;
  final double totalStorage;
  final double usedStorage;

  StorageUsageBar({
    required this.controller,
    required this.usagePercentage,
    required this.totalStorage,
    required this.usedStorage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    return CircularProgressIndicator(
                      value: controller.value * usagePercentage,
                      strokeWidth: 12,
                    );
                  },
                ),
              ),
              Text(
                "${(usagePercentage * 100).toStringAsFixed(1)}%",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            "Used: ${usedStorage.toStringAsFixed(2)} GB of ${totalStorage.toStringAsFixed(2)} GB",
            style: TextStyle(
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
