import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/storage/media_store.dart';
import '../../../data/repositories/vehicle_photo_repository.dart';

class VehiclePhotosScreen extends StatefulWidget {
  const VehiclePhotosScreen({super.key, required this.vehicleId});
  final int vehicleId;
  @override
  State<VehiclePhotosScreen> createState() => _VehiclePhotosScreenState();
}

class _VehiclePhotosScreenState extends State<VehiclePhotosScreen> {
  Map<String, String> _photos = {};
  bool _loading = true;
  final _damageNote = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _damageNote.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final value = await VehiclePhotoRepository.instance.get(widget.vehicleId);
    if (mounted)
      setState(() {
        _photos = value;
        _loading = false;
      });
  }

  Future<void> _pick(String kind) async {
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (c) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Prendre une photo'),
                  onTap: () => Navigator.pop(c, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choisir une photo'),
                  onTap: () => Navigator.pop(c, ImageSource.gallery))
            ])));
    if (source == null) return;
    final x = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (x == null) return;
    await VehiclePhotoRepository.instance.save(
        widget.vehicleId, kind, File(x.path),
        note: kind == 'damage' ? _damageNote.text.trim() : null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final names = {
      'front': 'Avant',
      'back': 'Arrière',
      'left': 'Gauche',
      'right': 'Droite',
      'damage': 'Dégâts existants'
    };
    return Scaffold(
        appBar: AppBar(title: const Text('Photos et dégâts')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Photos extérieures',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Expanded(
                          child: GridView.count(
                              crossAxisCount: 2,
                              childAspectRatio: 1.2,
                              children: names.entries.map((e) {
                                final path = MediaStore.instance
                                    .resolveFile(_photos[e.key]);
                                return Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                        onTap: () => _pick(e.key),
                                        child: path == null
                                            ? Center(
                                                child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                    const Icon(Icons
                                                        .add_a_photo_outlined),
                                                    Text(e.value)
                                                  ]))
                                            : Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                    Image.file(path,
                                                        fit: BoxFit.cover),
                                                    Positioned(
                                                        bottom: 4,
                                                        left: 4,
                                                        child: Chip(
                                                            label:
                                                                Text(e.value)))
                                                  ])));
                              }).toList())),
                      TextField(
                          controller: _damageNote,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'Note sur les dégâts existants'))
                    ])));
  }
}
