import 'dart:math';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'dart:io'; 

class VideoManagerPage extends StatefulWidget {
  const VideoManagerPage({super.key});

  @override
  _VideoManagerPageState createState() => _VideoManagerPageState();
}

class _VideoManagerPageState extends State<VideoManagerPage> {
  List<AssetEntity> _videos = [];
  Map<AssetEntity, bool> selectedVideos = {};
  bool allSelected = false;
  String sortOrder = 'Newest to Oldest';
  int totalVideoSize = 0;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    final PermissionState permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      return;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.video);

    if (albums.isNotEmpty) {
      final AssetPathEntity firstAlbum = albums.first;
      final List<AssetEntity> videos = await firstAlbum.getAssetListPaged(page: 0, size: 100);
      int totalSize = 0;

      for (var video in videos) {
        final file = await video.originFile;
        totalSize += file?.lengthSync() ?? 0;
      }

      setState(() {
        _videos = videos;
        selectedVideos = {for (var video in videos) video: false};
        totalVideoSize = totalSize;
      });
    }
  }

  String formatBytes(int bytes, int decimals) {
    if (bytes == 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) + " " + suffixes[i];
  }

  Future<String> _calculateVideoSize(AssetEntity video) async {
    final file = await video.originFile;
    final sizeInMB = (file?.lengthSync() ?? 0) / (1024 * 1024);
    return '${sizeInMB.toStringAsFixed(2)} MB';
  }

  void _toggleSelection(AssetEntity video) {
    setState(() {
      selectedVideos[video] = !(selectedVideos[video] ?? false);
    });
  }

  void _toggleAllSelections() {
    setState(() {
      allSelected = !allSelected;
      selectedVideos.updateAll((key, value) => allSelected);
    });
  }

  void _sortVideos(String order) {
    setState(() {
      sortOrder = order;
      if (sortOrder == 'Newest to Oldest') {
        _videos.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      } else {
        _videos.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      }
    });
  }

  Future<void> _deleteSelectedVideos() async {
    List<String> selectedIds = selectedVideos.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key.id)
        .toList();
    
    if (selectedIds.isNotEmpty) {
      await PhotoManager.editor.deleteWithIds(selectedIds);
      setState(() {
        _videos.removeWhere((video) => selectedVideos[video] == true);
        selectedVideos.removeWhere((key, value) => value);
      });
    }
  }

  int getSelectedCount() {
    return selectedVideos.values.where((value) => value).length;
  }

  Future<int> getSelectedVideosSize() async {
    int totalSize = 0;
    for (var entry in selectedVideos.entries) {
      if (entry.value) {
        final file = await entry.key.originFile;
        totalSize += file?.lengthSync() ?? 0;
      }
    }
    return totalSize;
  }

  bool get hasSelectedVideos => getSelectedCount() > 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organize Videos'),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: _toggleAllSelections,
            icon: const Icon(Icons.select_all),
            label: Text(allSelected ? 'Deselect All' : 'Select All'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: _sortVideos,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Newest to Oldest',
                child: Text('Newest to Oldest'),
              ),
              const PopupMenuItem(
                value: 'Oldest to Newest',
                child: Text('Oldest to Newest'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Total Video Size: ${formatBytes(totalVideoSize, 2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _videos.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _videos.length,
                    itemBuilder: (context, index) {
                      final video = _videos[index];
                      final isSelected = selectedVideos[video] ?? false;

                      return GestureDetector(
                        onTap: () => _openVideoPreview(video),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: FutureBuilder<Uint8List?>(
                                future: video.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.done &&
                                      snapshot.data != null) {
                                    return Image.memory(snapshot.data!,
                                        fit: BoxFit.cover, width: double.infinity);
                                  } else {
                                    return const CircularProgressIndicator();
                                  }
                                },
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(4.0),
                                child: FutureBuilder<String>(
                                  future: _calculateVideoSize(video),
                                  builder: (context, snapshot) {
                                    final size = snapshot.data ?? 'Loading...';
                                    final duration = _formatDuration(video.duration);
                                    return Text(
                                      '$size\n$duration',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (bool? value) {
                                  _toggleSelection(video);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (hasSelectedVideos)
            FutureBuilder<int>(
              future: getSelectedVideosSize(),
              builder: (context, snapshot) {
                final size = snapshot.hasData
                    ? formatBytes(snapshot.data!, 2)
                    : 'Calculating...';
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    onPressed: _deleteSelectedVideos,
                    icon: const Icon(Icons.delete),
                    label: Text('Delete ${getSelectedCount()} videos ($size)'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _openVideoPreview(AssetEntity video) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPreviewPage(
          video: video,
          refreshVideos: _loadVideos,
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    return duration.toString().split('.').first.padLeft(8, "0");
  }
}

class VideoPreviewPage extends StatefulWidget {
  final AssetEntity video;
  final Function refreshVideos;

  const VideoPreviewPage({super.key, required this.video, required this.refreshVideos});

  @override
  _VideoPreviewPageState createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  late VideoPlayerController _controller;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() async {
    final file = await widget.video.file;

    if (file != null) {
      try {
        _controller = VideoPlayerController.file(file)
          ..initialize().then((_) {
            setState(() {});
          }).catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to load video preview')),
            );
          });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading video file')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video file not found')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> _calculateVideoSize() async {
    final file = await widget.video.originFile;
    final sizeInMB = (file?.lengthSync() ?? 0) / (1024 * 1024);
    return '${sizeInMB.toStringAsFixed(2)} MB';
  }

  Future<void> _deleteVideo(BuildContext context) async {
    List<String> deletedIds = await PhotoManager.editor.deleteWithIds([widget.video.id]);
    if (deletedIds.isNotEmpty) {
      widget.refreshVideos();
      Navigator.pop(context, true);
    } else {
      widget.refreshVideos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete the video')),
      );
    }
  }

  Future<void> _compressVideo(BuildContext context) async {
    final originalFile = await widget.video.originFile;
    if (originalFile != null) {
      final outputPath = originalFile.path.replaceAll('.mp4', '_compressed.mp4');

      final arguments = [
        '-i', originalFile.path,
        '-b:v', '1M',
        outputPath
      ];

      try {
        final result = await FFmpegKit.execute(arguments.join(' '));

        if (ReturnCode.isSuccess(result.getReturnCode() as ReturnCode?)) {
          final compressedFile = File(outputPath);
          final originalSize = originalFile.lengthSync();
          final compressedSize = compressedFile.lengthSync();

          await compressedFile.rename(originalFile.path);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Video compressed! Original: ${(originalSize / (1024 * 1024)).toStringAsFixed(2)} MB, Compressed: ${(compressedSize / (1024 * 1024)).toStringAsFixed(2)} MB'),
            ),
          );

          widget.refreshVideos();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to compress video. FFmpeg result code: ${result.getReturnCode()}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during compression: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original file not found')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Preview'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_controller),
                          if (!isPlaying)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _controller.play();
                                  isPlaying = true;
                                });
                              },
                              child: const Icon(
                                Icons.play_circle_filled,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                          if (isPlaying)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _controller.pause();
                                  isPlaying = false;
                                });
                              },
                              child: const Icon(
                                Icons.pause_circle_filled,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          FutureBuilder<String>(
            future: _calculateVideoSize(),
            builder: (context, snapshot) {
              final size = snapshot.data ?? 'Calculating size...';
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => _deleteVideo(context),
                      icon: const Icon(Icons.delete),
                      label: Text('Delete Video ($size)'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      onPressed: () => _compressVideo(context),
                      icon: const Icon(Icons.compress),
                      label: const Text('Compress Video'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
