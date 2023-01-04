import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mmdb_app/volume.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Manga implements Comparable<Manga> {
  final String uuid;
  final String author;
  final String mangaka;
  final String genre;
  final String editor;
  final String title;
  final String titleOriginal;

  ///Default constructor
  const Manga({
    required this.uuid,
    required this.author,
    required this.mangaka,
    required this.genre,
    required this.editor,
    required this.title,
    required this.titleOriginal,
  });

  ///Firebase database volume constructor
  factory Manga.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();

    return Manga(
      uuid: data?['mangaUUID'] ?? snapshot.id,
      author: data?['mangaAuthor'] ?? emptyManga.author,
      mangaka: data?['mangaMangaka'] ?? emptyManga.mangaka,
      genre: data?['mangaGenre'] ?? emptyManga.genre,
      editor: data?['mangaEditor'] ?? emptyManga.editor,
      title: data?['mangaTitle'] ?? emptyManga.title,
      titleOriginal: data?['mangaTitleOriginal'] ?? emptyManga.titleOriginal,
    );
  }

  /// WARNING: blocking function! sperimental!
  static Future<Manga> fromUUID(String uuid) async {
    Manga manga = emptyManga;
    final db = FirebaseFirestore.instance;
    var res = await db
        .collection('mangas')
        .doc(uuid)
        .withConverter(
            fromFirestore: Manga.fromFirestore,
            toFirestore: (m, _) => m.toFirestore())
        .get();
    manga = res.data()!;
    return manga;
  }

  /// Mapping volume
  Map<String, dynamic> toFirestore() {
    if (uuid == emptyManga.uuid) {
      return {};
    }
    return {
      "mangaUUID": uuid,
      "mangaAuthor": author,
      "mangaMangaka": mangaka,
      "mangaGenre": genre,
      "mangaEditor": editor,
      "mangaTitle": title,
      "mangaTitleOriginal": titleOriginal,
    };
  }

  /// Manga a,b:
  /// <li> a.uuid == b.uuid -> a==b
  /// <li> a.uuid != b.uuid -> compare titles
  @override
  int compareTo(Manga other) {
    if (uuid == other.uuid) {
      return 0;
    }
    return title.compareTo(other.title);
  }

  @override
  String toString() {
    return '''{"mangaUUID":$uuid,
        "mangaTitle": $title,
        "mangaTitleOriginal": $titleOriginal,
        "mangaGenre": $genre,
        "mangaAuthor": $author,
        "mangaMangaka": $mangaka,
        "mangaEditor": $editor,
        ''';
  }

  ///Returns the list of all the volumes of the manga
  Future<List<Volume>> getAllVolumesList() async {
    WidgetsFlutterBinding.ensureInitialized();
    final db = FirebaseFirestore.instance;
    final List<Volume> volumeList = <Volume>[];
    final query = db
        .collection('volumes')
        .where('volumeMangaUUID', isEqualTo: uuid)
        .withConverter(
            fromFirestore: Volume.fromFirebase,
            toFirestore: (volume, _) => volume.toFirestore());

    final volumes = await query.get();
    for (var element in volumes.docs) {
      volumeList.add(element.data());
    }
    volumeList.sort();
    return volumeList;
  }

  /// Returns the list of all the non variant volumes of the manga
  Future<List<Volume>> getNormalVolumesList() async {
    final db = FirebaseFirestore.instance;
    final List<Volume> volumeList = <Volume>[];
    final query = db
        .collection('volumes')
        .where('volumeMangaUUID', isEqualTo: uuid)
        .where('volumeIsVariant', isEqualTo: false)
        .withConverter(
            fromFirestore: Volume.fromFirebase,
            toFirestore: (volume, _) => volume.toFirestore());

    final volumes = await query.get();
    for (var element in volumes.docs) {
      volumeList.add(element.data());
    }
    return volumeList;
  }

  /// Returns the list of all the variant volumes of the manga
  Future<List<Volume>> getVariantVolumesList() async {
    final db = FirebaseFirestore.instance;
    final List<Volume> volumeList = <Volume>[];
    final query = db
        .collection('volumes')
        .where('volumeMangaUUID', isEqualTo: uuid)
        .where('volumeIsVariant', isEqualTo: true)
        .withConverter(
            fromFirestore: Volume.fromFirebase,
            toFirestore: (volume, _) => volume.toFirestore());

    final volumes = await query.get();
    for (var element in volumes.docs) {
      volumeList.add(element.data());
    }
    return volumeList;
  }

  /// Returns every non variant volume cover of the manga
  Future<List<Image>> getNormalVolumesCovers() async {
    final volumes = await getNormalVolumesList();
    volumes.sort();
    return volumes.map((e) => e.getVolumeImage()).toList();
  }

  /// Returns every volume cover of the manga
  Future<List<Image>> getAllVolumesCovers() async {
    final volumes = await getAllVolumesList();
    volumes.sort();
    //print(volumes);
    return volumes.map((e) => e.getVolumeImage()).toList();
  }

  /// Returns every non variant volume cover of the manga
  Future<List<Image>> getVariantVolumesCovers() async {
    final volumes = await getNormalVolumesList();
    volumes.sort();
    return volumes.map((e) => e.getVolumeImage()).toList();
  }

  /// Adds every volume of the manga to the user library
  /// <li> userUUID -> the uuid of the user
  void addEveryVolumeToLibrary(String userUUID, BuildContext context) {
    getAllVolumesList()
        .then((value) => value.forEach((element) =>
            element.addToLibrary([userUUID, context], showSnackBar: false)))
        .then((value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!
                .addedEveryVolumeToLibraryLabel))));
  }
}

///Default empty manga in case of errors
const Manga emptyManga = Manga(
  uuid: 'MangaNotFound',
  title: 'MangaNotFound',
  titleOriginal: 'MangaNotFound',
  genre: 'MangaNotFound',
  author: 'MangaNotFound',
  mangaka: 'MangaNotFound',
  editor: 'MangaNotFound',
);
