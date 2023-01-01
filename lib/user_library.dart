import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mmdb_app/volume.dart';
import 'package:mmdb_app/manga.dart';

class UserLibrary {
  final String uuid;
  final List<String> savedMangasUUIDs;
  final Map<String, List<String>> savedVolumesUUIDs;
  List<Manga> savedMangas = <Manga>[];
  Map<Manga, List<Volume>> savedVolumes = {};

  ///default constructor
  UserLibrary(
      {required this.uuid,
      required this.savedMangasUUIDs,
      required this.savedVolumesUUIDs});

  factory UserLibrary.emptyLibrary(uuid) {
    return UserLibrary(uuid: uuid, savedMangasUUIDs: [], savedVolumesUUIDs: {});
  }

  factory UserLibrary.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data()!;
    final Map<String, List<String>> savedVolumes = {};
    print(
        "UserLibrary.fromFireStore(): data['userMangaUUIDList'].runtimeType = ${data['userMangaUUIDList'].toString().replaceAll(RegExp(r"\[|\]| "), "").split(',').runtimeType}");
    for (String mangaUUID in data['userMangaUUIDList']) {
      savedVolumes.putIfAbsent(
          mangaUUID,
          () => data[mangaUUID]
              .toString()
              .replaceAll(RegExp(r"\[|\]| "), "")
              .split(','));
    }

    return UserLibrary(
        uuid: snapshot.id,
        savedMangasUUIDs: data['userMangaUUIDList']
            .toString()
            .replaceAll(RegExp(r"\[|\]| "), "")
            .split(','),
        savedVolumesUUIDs: savedVolumes);
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> data = {};
    data.putIfAbsent('userMangaUUIDList', () => savedMangasUUIDs);
    for (var entry in savedVolumesUUIDs.entries) {
      data.putIfAbsent(entry.key, () => entry.value);
    }
    return data;
  }

  bool isEmpty() {
    return savedMangasUUIDs.isEmpty;
  }

  Future<List<Manga>> getSavedMangas() async {
    if (savedMangas.isEmpty) {
      for (var mangaUUID in savedMangasUUIDs) {
        savedMangas.add(await Manga.fromUUID(mangaUUID));
      }
      savedMangas.sort();
    }

    return savedMangas;
  }

  Future<List<Volume>> getSavedVolumesForManga(Manga manga) async {
    if (!savedVolumes.containsKey(manga)) {
      List<Volume> vols = <Volume>[];
      for (var volumeUUID in savedVolumesUUIDs[manga.uuid]!) {
        vols.add(await Volume.getVolumeByUUID(volumeUUID));
      }
      vols.sort();
      savedVolumes.putIfAbsent(manga, () => vols);
    }
    print(
        "LibraryPage.userLibrary.getSavedVolumesForManga: savedVolumes(${manga.title}) = ${savedVolumes[manga]!.map((e) => e.uuid).toList().toString()}");
    return savedVolumes[manga]!;
  }
}
