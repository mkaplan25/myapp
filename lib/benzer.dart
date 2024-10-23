import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:myapp/utils/image_utils.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için

class BenzerSayfa extends StatefulWidget {
  const BenzerSayfa({super.key});

  @override
  _BenzerSayfaState createState() => _BenzerSayfaState();
}

class _BenzerSayfaState extends State<BenzerSayfa> {
  List<AssetPathEntity>? _albums;
  List<AssetEntity>? _photos;
  Map<String, List<AssetEntity>> groupedPhotos = {};
  Map<AssetEntity, bool> selectedPhotos = {};
  bool sortByDate = false;
  String? selectedSortOrder;
  DateTimeRange? selectedDateRange;
  bool allSelected = true; // İlk başta hepsi seçili gelmesin diye false yapıldı

  @override
  void initState() {
    super.initState();
    _loadAllPhotos();
  }

  void openGroupPreview(BuildContext context, List<AssetEntity> photos) async {
    // Önizleme sayfası açılır ve geri dönüldüğünde seçimler güncellenir
    final updatedSelectedPhotos = await Navigator.push<Map<AssetEntity, bool>>(
      context,
      MaterialPageRoute(
        builder: (context) => GroupPreviewPage(
          photos: photos,
          selectedPhotos: Map.from(selectedPhotos), // Kopyasını gönderiyoruz
        ),
      ),
    );

    if (updatedSelectedPhotos != null) {
      setState(() {
        // Geri dönen seçimlerle ana ekranı güncelliyoruz
        selectedPhotos.addAll(updatedSelectedPhotos);
      });
    }
  }

  // Fotoğrafları yükle
 Future<void> _loadAllPhotos() async {
  final PermissionState permission = await PhotoManager.requestPermissionExtend();
  if (!permission.isAuth) {
    return; // İzin verilmediyse işlemi sonlandır
}

  final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.image);

  if (albums.isNotEmpty) {
    final AssetPathEntity firstAlbum = albums.first;
    List<AssetEntity> allPhotos = [];
    const int pageSize = 100; 
    int totalAssets = await firstAlbum.assetCountAsync;
    int totalPages = (totalAssets / pageSize).ceil();

    List<Future<List<AssetEntity>>> futures = [];

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      futures.add(firstAlbum.getAssetListPaged(page: pageIndex, size: pageSize));
    }

    List<List<AssetEntity>> pages = await Future.wait(futures);

    for (var photoList in pages) {
      allPhotos.addAll(photoList);
    }

    setState(() {
      _photos = allPhotos;
    });

    await _groupSimilarPhotos();
  }
}




  // Fotoğrafları hash ile gruplandır
  Future<void> _groupSimilarPhotos() async {
  Map<String, List<AssetEntity>> newGroupedPhotos = {};

  await Future.forEach(_photos!, (photo) async {
    Uint8List? data = await photo.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    String hash = generateImageHash(data!);
    newGroupedPhotos.putIfAbsent(hash, () => []).add(photo);
    });

  setState(() {
    groupedPhotos = newGroupedPhotos;
    groupedPhotos.forEach((hash, photos) {
      for (int i = 0; i < photos.length; i++) {
        selectedPhotos[photos[i]] = i != 0;
      }
    });
  });
}

  // Görüntü verilerinden hash oluştur
  String generateImageHash(Uint8List imageData) {
    img.Image? image = img.decodeImage(imageData);
    if (image == null) {
      return '';
    }
    String pHash = calculatePHash(image);
    return pHash;
  }

  // Seçili olan fotoğrafları silme fonksiyonu
  Future<void> deleteSelectedPhotos() async {
    List<String> selectedPhotoIds = selectedPhotos.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key.id)
        .toList();

    bool deleted =
        (await PhotoManager.editor.deleteWithIds(selectedPhotoIds)) as bool;
    if (deleted) {
      setState(() {
        selectedPhotos.removeWhere((key, value) => value);
      });
      print('Seçili fotoğraflar silindi');
    } else {
      print('Fotoğraflar silinemedi');
    }
  }

  // Grubun tüm seçimlerini kaldır
  void clearSelectionsForGroup(String hash) {
    List<AssetEntity> photos = groupedPhotos[hash]!;
    setState(() {
      for (var photo in photos) {
        selectedPhotos[photo] = false;
      }
    });
  }

  // Tüm seçimleri kaldır veya hepsini seç butonu işlemleri
  void toggleAllSelections() {
    setState(() {
      if (allSelected) {
        // Hepsini kaldır
        selectedPhotos.updateAll((key, value) => false);
      } else {
        // Hepsini seç (bir tanesi hariç)
        groupedPhotos.forEach((hash, photos) {
          for (int i = 0; i < photos.length; i++) {
            selectedPhotos[photos[i]] =
                i != 0; // İlk fotoğraf hariç diğerlerini seç
          }
        });
      }
      // İşlem gerçekleştikten sonra flag'i güncelle
      allSelected = !allSelected;
    });
  }

  // Tarih aralığı seçici
  Future<void> selectDateRange() async {
    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedRange != null && pickedRange != selectedDateRange) {
      setState(() {
        selectedDateRange = pickedRange;
      });
    }
  }

  // Tarihe göre sıralama
  void applySortOrder() {
    setState(() {
      if (selectedSortOrder == 'Eskiden Yeniye') {
        groupedPhotos.forEach((key, value) {
          value.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
        });
      } else if (selectedSortOrder == 'Yeniden Eskiye') {
        groupedPhotos.forEach((key, value) {
          value.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
        });
      }
    });
  }

  // Tüm fotoğrafların toplam boyutunu ve sayısını hesapla
  Future<String> calculateTotalPhotosInfo() async {
    int totalSizeBytes = 0;
    for (var photo in _photos!) {
      Uint8List? data = await photo.originBytes;
      totalSizeBytes += data?.length ?? 0;
    }
    double totalSizeMB = totalSizeBytes / (1024 * 1024);
    int totalCount = _photos?.length ?? 0;
    return '$totalCount fotoğraf (${totalSizeMB.toStringAsFixed(2)} MB)';
  }

  // Seçili olanları sil butonunun üstünde gösterilecek toplam boyut ve seçili fotoğraf sayısını al
  Future<String> getSelectedPhotosInfo() async {
    int totalSizeBytes = 0;
    for (var entry in selectedPhotos.entries) {
      if (entry.value) {
        AssetEntity photo = entry.key;
        Uint8List? data = await photo.originBytes;
        totalSizeBytes += data?.length ?? 0;
      }
    }
    double totalSizeMB = totalSizeBytes / (1024 * 1024);
    int selectedCount = selectedPhotos.values.where((value) => value).length;
    return '$selectedCount benzer fotoğrafı sil (${totalSizeMB.toStringAsFixed(2)} MB)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                
                floating: true,
                pinned: true,
                expandedHeight: 120.0,
                flexibleSpace: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    var top = constraints.biggest.height;
                    bool isCollapsed = top <
                        120.0; // Yükseklik 80'den küçükse daralmış sayılacak
                       
                    return FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 80, bottom: 5),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment
                            .spaceBetween, // Yazı sola, butonlar sağa hizalanacak
                        children: [
                          if (isCollapsed)
                            Text(
                              'Benzer Fotoğraflar', // Sol tarafta görünecek başlık
                              style: TextStyle(
                                fontSize: isCollapsed ? 16 : 18,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                          // Sağdaki butonlar (ikonlar)
                          Row(
                            children: [
                              if (isCollapsed)
                                // "Hepsini Seç" ikonu
                                IconButton(
                                  onPressed: toggleAllSelections,
                                  icon: const Icon(Icons.select_all,
                                      color: Colors.black),
                                ),
                              const SizedBox(
                                  width: 8), // Butonlar arasında boşluk ekleyin

                              // Sıralama ikonu
                              if (isCollapsed)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.sort, color: Colors.black),
                                  onSelected: (value) {
                                    setState(() {
                                      selectedSortOrder =
                                          value; // Sıralama seçeneğini ayarlayın
                                    });
                                    applySortOrder(); // Sıralama işlevini uygulayın
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'Eskiden Yeniye',
                                      child: Text('Eskiden Yeniye'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'Yeniden Eskiye',
                                      child: Text('Yeniden Eskiye'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                     
                      background: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment
                              .end, // İçerikleri en alta hizalar
                          crossAxisAlignment:
                              CrossAxisAlignment.start, // Sol hizalı yapar
                          children: [
                            // "Benzer Fotoğraflar" başlığı ve "Tarih Aralığı Seç" butonunu aynı satıra ekliyoruz
                            Row(
                              mainAxisAlignment: MainAxisAlignment
                                  .spaceBetween, // İki öğeyi satırın sağına ve soluna hizalar
                              children: [
                                const Text(
                                  'Benzer Fotoğraflar',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors
                                        .black, // Başlığın rengini ayarlayın
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    // Tarih aralığı seçimi için tarih aralığı seçici açılır
                                    DateTimeRange? selectedRange =
                                        await showDateRangePicker(
                                      context: context,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now(),
                                    );
                                    if (selectedRange != null) {
                                      // Seçilen tarih aralığını güncelleyebilirsiniz
                                      setState(() {
                                        selectedDateRange = selectedRange;
                                      });
                                    }
                                  },
                                  child: Text(
                                    selectedDateRange == null
                                        ? 'Tarih Aralığı Seç' // Eğer tarih aralığı seçilmemişse
                                        : '${DateFormat('dd/MM/yyyy').format(selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(selectedDateRange!.end)}', // Seçilen tarih aralığı
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14), // Butonun yazı stili
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                                height:
                                    0), // Başlık ve fotoğraf bilgisi arasında boşluk

                            // Toplam fotoğraf ve boyut bilgisi
                            FutureBuilder<String>(
                              future:
                                  calculateTotalPhotosInfo(), // Fotoğraf bilgisi getiren fonksiyon
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Text(
                                    'Yükleniyor...', // Yüklenirken gösterilecek metin
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.blueGrey),
                                  );
                                } else {
                                  return Text(
                                    snapshot.data ??
                                        '', // Fotoğraf sayısı ve boyutu bilgisi
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    String hash = groupedPhotos.keys.elementAt(index);
                    List<AssetEntity> photos = groupedPhotos[hash]!;

                    if (photos.length > 1) {
                      return GestureDetector(
                        onTap: () => openGroupPreview(context,
                            photos), // Gruba tıklandığında önizleme sayfası açılır
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${photos.length} benzer fotoğraf'),
                                      TextButton(
                                        onPressed: () =>
                                            clearSelectionsForGroup(hash),
                                        child: const Text('Hiçbirini Seçme'),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 200,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: photos.length,
                                      itemBuilder: (context, photoIndex) {
                                        AssetEntity photo = photos[photoIndex];
                                        bool isSelected =
                                            selectedPhotos[photo] ?? false;

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0),
                                          child: Stack(
                                            children: [
                                              FutureBuilder<Uint8List?>(
                                                future: photo.thumbnailData,
                                                builder: (context, snapshot) {
                                                  if (snapshot
                                                          .connectionState ==
                                                      ConnectionState.done) {
                                                    return snapshot.data != null
                                                        ? Image.memory(
                                                            snapshot.data!,
                                                            width: 200,
                                                            height: 200,
                                                            fit: BoxFit.cover)
                                                        : const Icon(Icons.image,
                                                            size: 100);
                                                  } else {
                                                    return const CircularProgressIndicator();
                                                  }
                                                },
                                              ),
                                              Positioned(
                                                top: 0,
                                                left: 0,
                                                child: Checkbox(
                                                  value: isSelected,
                                                  onChanged: (bool? value) {
                                                    setState(() {
                                                      selectedPhotos[photo] =
                                                          value!;
                                                    });
                                                  },
                                                ),
                                              ),
                                              if (!isSelected)
                                                Positioned(
                                                  bottom: 0,
                                                  left: 0,
                                                  child: Container(
                                                    color: Colors.blue,
                                                    padding:
                                                        const EdgeInsets.all(4.0),
                                                    child: const Row(
                                                      children: [
                                                        Icon(Icons.star,
                                                            color: Colors.white,
                                                            size: 16),
                                                        SizedBox(width: 4),
                                                        Text('En İyi',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                      ],
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
                          ),
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                  childCount: groupedPhotos.length,
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 80), // Alttaki butona yer bırakıyoruz
              ),
            ],
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: FutureBuilder<String>(
              future: getSelectedPhotosInfo(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      backgroundColor:
                          Colors.blue, // Butonun rengini mavi yapıyoruz
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onPressed: deleteSelectedPhotos,
                    child: Text(snapshot.data ?? 'Seçili olanları sil',
                        style: const TextStyle(fontSize: 18)),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GroupPreviewPage extends StatefulWidget {
  final List<AssetEntity> photos;
  final Map<AssetEntity, bool> selectedPhotos;

  const GroupPreviewPage(
      {super.key, required this.photos, required this.selectedPhotos});

  @override
  _GroupPreviewPageState createState() => _GroupPreviewPageState();
}

class _GroupPreviewPageState extends State<GroupPreviewPage> {
  int currentIndex = 0;

  // Seçimi yapma veya bırakma işlemi
  void selectPhoto(AssetEntity photo) {
    setState(() {
      widget.selectedPhotos[photo] = !(widget.selectedPhotos[photo] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Geri dönerken güncellenmiş seçimleri geri gönderiyoruz
        Navigator.pop(context, widget.selectedPhotos);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grup Önizleme'),
        ),
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                itemCount: widget.photos.length,
                controller: PageController(initialPage: currentIndex),
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  AssetEntity photo = widget.photos[index];
                  return FutureBuilder<Uint8List?>(
                    future: photo.originBytes,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return snapshot.data != null
                            ? Image.memory(snapshot.data!, fit: BoxFit.contain)
                            : const Icon(Icons.image, size: 100);
                      } else {
                        return const Center(child: CircularProgressIndicator());
                      }
                    },
                  );
                },
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.photos.length,
                itemBuilder: (context, index) {
                  AssetEntity photo = widget.photos[index];
                  bool isSelected = widget.selectedPhotos[photo] ?? false;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        currentIndex = index;
                      });
                    },
                    child: Stack(
                      children: [
                        FutureBuilder<Uint8List?>(
                          future: photo.thumbnailData,
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
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              selectPhoto(photo); // Seçim işlemi
                            },
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
