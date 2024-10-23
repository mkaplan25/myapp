import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';

class ScreenshotManager extends StatefulWidget {
  @override
  _ScreenshotManagerState createState() => _ScreenshotManagerState();
}

class _ScreenshotManagerState extends State<ScreenshotManager> {
  List<AssetEntity> screenshots = [];
  Map<AssetEntity, bool> selectedPhotos = {};
  bool allSelected = true;
  String selectedSortOrder = 'Newest to Oldest';

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      _loadScreenshots();
    } else {
      PhotoManager.openSetting(); // Open settings if permission is denied
    }
  }

  Future<void> _loadScreenshots() async {
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      filterOption: FilterOptionGroup(
        imageOption: FilterOption(
          needTitle: true,
          sizeConstraint: SizeConstraint(minWidth: 100, minHeight: 100),
        ),
        orders: [
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    for (AssetPathEntity album in albums) {
      if (album.name.toLowerCase() == "screenshots") {
        List<AssetEntity> media =
            await album.getAssetListPaged(page: 0, size: 100);
        setState(() {
          screenshots = media;
          selectedPhotos = {for (var photo in media) photo: true};
        });
        break;
      }
    }
  }

  void _toggleSelection(AssetEntity screenshot) {
    setState(() {
      selectedPhotos[screenshot] = !(selectedPhotos[screenshot] ?? false);
    });
  }

  void _sortScreenshots(String sortOrder) {
    setState(() {
      selectedSortOrder = sortOrder;
      if (sortOrder == 'Newest to Oldest') {
        screenshots
            .sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      } else {
        screenshots
            .sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      }
    });
  }

  Future<int> _calculateTotalSize() async {
    int totalSize = 0;
    for (var screenshot in screenshots) {
      int? fileLength =
          await screenshot.originFile.then((file) => file?.length());
      totalSize += fileLength!;
    }
    return totalSize;
  }

  // Grup önizlemesi (tam ekran galeri formatı)
  void _openGalleryPreview(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupPreviewPage(
          photos: screenshots,
          selectedPhotos: selectedPhotos,
          initialIndex: initialIndex,
        ),
      ),
    ).then((updatedSelections) {
      setState(() {
        if (updatedSelections != null) {
          selectedPhotos = updatedSelections;
        }
      });
    });
  }

  // Silme işlemi için sayfayı yenileme
  Future<void> _deleteSelectedPhotos() async {
    List<String> idsToDelete = selectedPhotos.keys
        .where((photo) => selectedPhotos[photo]!)
        .map((photo) => photo.id)
        .toList();

    try {
      // Silme işlemi, eğer silme başarısız olursa boş bir liste döner
      List<String> failedDeletions =
          await PhotoManager.editor.deleteWithIds(idsToDelete);

      // Eğer boş bir liste dönerse, tüm silmeler başarılıdır
      bool deleteSuccess = failedDeletions.isEmpty;

      // Sayfayı yenileyelim
      setState(() {
        _loadScreenshots();
      });

      if (!deleteSuccess) {
        // Silme başarısızsa kullanıcıya bildirim gösterelim
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected photos deleted successfully')),
        );
      } else {
        // Silme başarılı olursa bildirim gösterelim
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Some photos failed to delete or permission denied')),
        );
      }
    } catch (e) {
      // Hata durumunda sayfayı yenile ve hatayı bildir
      setState(() {
        _loadScreenshots();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred during deletion: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Screenshot Manager'),
        actions: [
          if (selectedPhotos.values.contains(true))
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _deleteSelectedPhotos,
              icon: Icon(Icons.delete),
              label: Text('Delete Selected'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Güzel görünümlü butonlar
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      if (allSelected) {
                        selectedPhotos.updateAll((key, value) => false);
                        allSelected = false;
                      } else {
                        selectedPhotos.updateAll((key, value) => true);
                        allSelected = true;
                      }
                    });
                  },
                  icon: Icon(Icons.select_all),
                  label: Text(allSelected ? 'Deselect All' : 'Select All'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      selectedSortOrder =
                          selectedSortOrder == 'Newest to Oldest'
                              ? 'Oldest to Newest'
                              : 'Newest to Oldest';
                      _sortScreenshots(selectedSortOrder);
                    });
                  },
                  icon: Icon(Icons.sort),
                  label: Text(selectedSortOrder),
                ),
              ],
            ),
          ),
          FutureBuilder<int>(
            future: _calculateTotalSize(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text('Calculating size...');
              } else if (snapshot.hasError) {
                return Text('Error calculating size');
              }
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Total Screenshots: ${screenshots.length}, Total Size: ${(snapshot.data! / (1024 * 1024)).toStringAsFixed(2)} MB',
                  style: TextStyle(fontSize: 16),
                ),
              );
            },
          ),
          Expanded(
            child: screenshots.isEmpty
                ? Center(child: CircularProgressIndicator())
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // Kare formatında iki resim yan yana
                      crossAxisSpacing: 8, // Küçük boşluklar
                      mainAxisSpacing: 8,
                      childAspectRatio: 1, // Kare formatında
                    ),
                    itemCount: screenshots.length,
                    itemBuilder: (context, index) {
                      final screenshot = screenshots[index];
                      final isSelected = selectedPhotos[screenshot] ?? false;

                      return GestureDetector(
                        onTap: () {
                          _openGalleryPreview(
                              index); // Tam ekran galeri önizlemesi
                        },
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  16), // Hafif oval köşeler
                              child: FutureBuilder<Uint8List?>(
                                future: screenshot.thumbnailDataWithSize(
                                    ThumbnailSize(400, 400)),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                        child: CircularProgressIndicator());
                                  } else if (snapshot.hasError) {
                                    return Center(child: Icon(Icons.error));
                                  }
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  _toggleSelection(screenshot);
                                },
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.check_circle_outline,
                                  color:
                                      isSelected ? Colors.green : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Grup önizlemesi tam ekran galeri formatı
class GroupPreviewPage extends StatefulWidget {
  final List<AssetEntity> photos;
  final Map<AssetEntity, bool> selectedPhotos;
  final int initialIndex;

  const GroupPreviewPage({
    super.key,
    required this.photos,
    required this.selectedPhotos,
    required this.initialIndex,
  });

  @override
  _GroupPreviewPageState createState() => _GroupPreviewPageState();
}

class _GroupPreviewPageState extends State<GroupPreviewPage> {
  int currentIndex = 0;
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex);
    _thumbnailScrollController = ScrollController();
  }

  // Fotoğraf seçimi yapma veya kaldırma işlemi
  void selectPhoto(AssetEntity photo) {
    setState(() {
      widget.selectedPhotos[photo] = !(widget.selectedPhotos[photo] ?? false);
    });
  }

  void _scrollThumbnailToIndex(int index) {
    double offset = index * 88.0; // Küçük resim genişliği + padding
    _thumbnailScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Geri tuşuna basıldığında güncellenmiş seçimleri geri gönder
        Navigator.pop(context, widget.selectedPhotos);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Group Preview'),
        ),
        body: Column(
          children: [
            // Büyük görüntü alanı
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.photos.length,
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                    _scrollThumbnailToIndex(
                        index); // Alttaki küçük resimlerin senkronize kayması
                  });
                },
                itemBuilder: (context, index) {
                  AssetEntity photo = widget.photos[index];
                  bool isSelected = widget.selectedPhotos[photo] ?? false;
                  return Stack(
                    children: [
                      Center(
                        child: FutureBuilder<Uint8List?>(
                          future: photo.originBytes,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              return snapshot.data != null
                                  ? Image.memory(snapshot.data!,
                                      fit: BoxFit.contain)
                                  : const Icon(Icons.image, size: 100);
                            } else {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                          },
                        ),
                      ),
                      // Büyük görüntüde seçim işlemi
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () {
                            selectPhoto(photo);
                          },
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            color: isSelected ? Colors.green : Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Küçük resim galerisi
            SizedBox(
              height: 100,
              child: ListView.builder(
                controller: _thumbnailScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: widget.photos.length,
                itemBuilder: (context, index) {
                  AssetEntity photo = widget.photos[index];
                  bool isSelected = widget.selectedPhotos[photo] ?? false;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        currentIndex = index;
                        _pageController
                            .jumpToPage(index); // Büyük resim sayfasına git
                      });
                    },
                    child: Stack(
                      children: [
                        FutureBuilder<Uint8List?>(
                          future: photo
                              .thumbnailDataWithSize(ThumbnailSize(200, 200)),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: snapshot.data != null
                                    ? Image.memory(snapshot.data!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover)
                                    : const Icon(Icons.image, size: 50),
                              );
                            } else {
                              return const CircularProgressIndicator();
                            }
                          },
                        ),
                        // Küçük resimde seçim işlemi
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              selectPhoto(photo);
                            },
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                              color: isSelected ? Colors.green : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
