import 'package:flutter/material.dart';
import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/media_store.dart';
import '../../../domain/entities/vehicle_photo.dart';
import '../../providers/vehicle_photo_provider.dart';

class VehiclePhotosScreen extends ConsumerStatefulWidget {
  const VehiclePhotosScreen({super.key, required this.vehicleId});
  final int vehicleId;
  @override
  ConsumerState<VehiclePhotosScreen> createState() =>
      _VehiclePhotosScreenState();
}

class _VehiclePhotosScreenState extends ConsumerState<VehiclePhotosScreen> {
  final _damageNote = TextEditingController();
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _damageNote.dispose();
    super.dispose();
  }

  Future<void> _pick(VehiclePhotoKind kind) async {
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (c) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const AppText(AppCopy.takeAPhoto),
                  onTap: () => Navigator.pop(c, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const AppText(AppCopy.chooseAPhoto),
                  onTap: () => Navigator.pop(c, ImageSource.gallery))
            ])));
    if (source == null) return;
    final x = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (x == null) return;
    await ref.read(replaceVehiclePhotoProvider)(
      vehicleId: widget.vehicleId,
      kind: kind,
      sourcePath: x.path,
      note: kind == VehiclePhotoKind.damage ? _damageNote.text.trim() : null,
    );
    ref.invalidate(vehiclePhotosProvider(widget.vehicleId));
  }

  @override
  Widget build(BuildContext context) {
    final names = <VehiclePhotoKind, String>{
      VehiclePhotoKind.front: AppCopy.front,
      VehiclePhotoKind.back: AppCopy.back1a55ee,
      VehiclePhotoKind.left: AppCopy.left,
      VehiclePhotoKind.right: AppCopy.right,
      VehiclePhotoKind.damage: AppCopy.existingDamagef545de,
    };
    final photos = ref.watch(vehiclePhotosProvider(widget.vehicleId));
    return Scaffold(
        appBar: AppBar(title: const AppText(AppCopy.photosAndDamage)),
        body: photos.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: AppText(context.trError(error))),
          data: (storedPhotos) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppText(AppCopy.exteriorPhotos,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Expanded(
                        child: GridView.count(
                            crossAxisCount: 2,
                            childAspectRatio: 1.2,
                            children: names.entries.map((e) {
                              final path = MediaStore.instance
                                  .resolveFile(storedPhotos[e.key]);
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
                                                  AppText(e.value)
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
                                                              AppText(e.value)))
                                                ])));
                            }).toList())),
                    TextField(
                        controller: _damageNote,
                        maxLines: 2,
                        decoration: InputDecoration(
                            labelText: context.tr(AppCopy.existingDamageNote)))
                  ])),
        ));
  }
}
