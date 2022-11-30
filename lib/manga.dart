import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:mmdb_app/network.dart';
import 'package:shared_preferences/shared_preferences.dart';

// TODO add comparator
class Manga implements Comparable<Manga> {
  const Manga(
      {required this.uuid,
      required this.title,
      required this.titleOriginal,
      required this.genres,
      required this.story,
      required this.design,
      required this.editor,
      required this.volumes,
      required this.variants,
      required this.imgDir,
      required this.imgName});

  factory Manga.fromJson(dynamic js) {
    Manga m = Manga(
        uuid: js['uuid'],
        title: js['title'],
        titleOriginal: js['title-original'],
        genres: <String>[for (final x in js['genres']) x],
        story: js['story'],
        design: js['designs'],
        editor: js['editor'],
        volumes: <int>[for (final x in js['volumes']) x],
        variants: <int>[for (final x in js['variants']) x],
        imgDir: js['img-dir'],
        imgName: js['img-name']);

    return m;
  }

  final String uuid;
  final String title;
  final String titleOriginal;
  final List<String> genres;
  final String story;
  final String design;
  final String editor;
  final List<int> volumes;
  final List<int> variants;
  final String imgDir;
  final String imgName;

  @override
  String toString() {
    return '''{"uuid":$uuid,
        "title": $title,
        "title-original": $titleOriginal,
        "genres": $genres,
        "story": $story,
        "designs": $design,
        "editor": $editor,
        "volumes": $volumes,
        "variants": $variants,
        "img-dir":$imgDir,
        "img-name":$imgName}''';
  }

  @override
  int compareTo(Manga other) {
    return this.title.compareTo(other.title);
  }

  void removeVolumeFromLibrary(
      BuildContext context, int volumeNumber, bool isVariant) {
    SharedPreferences.getInstance().then((db) {
      var volNumber = isVariant ? "-$volumeNumber" : "$volumeNumber";
      print(
          "removeVolumeFromLibrary(context,$volumeNumber,$isVariant): volNumber = $volNumber");
      final savedMangaList = db.getStringList('savedMangasUUID') ?? [];
      final savedVolumesList = db.getStringList(uuid) ?? [];

      if (savedVolumesList.contains(volNumber.toString())) {
        savedVolumesList.remove(volNumber.toString());
        if (savedVolumesList.isNotEmpty) {
          db.setStringList(uuid, savedVolumesList);
        } else {
          db.remove(uuid);
          savedMangaList.remove(uuid);
          savedMangaList.isEmpty
              ? db.remove('savedMangasUUID')
              : db.setStringList('savedMangasUUID', savedMangaList);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Volume successfully removed.')));
    });
  }

  void addVolumeToLibrary(
      BuildContext context, int volumeNumber, bool isVariant) {
    SharedPreferences.getInstance().then((db) {
      var volNumber = isVariant ? "-$volumeNumber" : "$volumeNumber";
      print(
          "addVolumeToLibrary(context,$volumeNumber,$isVariant): volNumber = $volNumber");
      final savedMangaList = db.getStringList('savedMangasUUID') ?? [];
      //first check if manga is already stored
      if (savedMangaList.contains(uuid)) {
        final savedVolumesList = db.getStringList(uuid) ?? [];
        if (!savedVolumesList.contains(volNumber)) {
          savedVolumesList.add(volNumber);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Volume added!')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Volume already in library.')));
        }
        db.setStringList(uuid, savedVolumesList);
      } else {
        savedMangaList.add(uuid);
        db.setStringList('savedMangasUUID', savedMangaList);
        db.setStringList(uuid, [volNumber.toString()]);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Volume added!')));
      }
    });
  }

  /// Returns the volume cover of the selected cover or 404 if not exist
  Image getVolumeCover({required int volumeNumber, bool isVariant = false}) {
    List<int> list = volumes;
    if (isVariant) {
      list = variants;
    }
    Image img;

    if (!list.contains(volumeNumber)) {
      img = const Image(
        image: AssetImage('static/404_not_found.jpg'),
      );
    }

    img = Image.network(
      Network.getMangaImageUrl(
        mangaImgDir: imgDir,
        mangaImgName: imgName,
        volumeNumber: volumeNumber.toString(),
        isVariant: isVariant,
      ),
      errorBuilder: (c, e, sT) =>
          const Image(image: AssetImage('static/404_not_found.jpg')),
      fit: BoxFit.fill,
    );

    return img;
  }

  /// Returns every non variant volume cover of the manga
  List<Image> getNormalVolumeCovers() {
    final covers = <Image>[];

    for (var volumeNumber in volumes) {
      covers.add(getVolumeCover(volumeNumber: volumeNumber));
    }
    return covers;
  }

  /// Returns every variant volume cover of the manga
  List<Image> getVariantVolumeCovers() {
    final covers = <Image>[];

    for (var variantNumber in variants) {
      covers.add(getVolumeCover(volumeNumber: variantNumber, isVariant: true));
    }

    return covers;
  }

  /// Returns every volume cover of the manga
  List<Image> getAllVolumeCovers() {
    final covers = <Image>[];
    covers.addAll(getNormalVolumeCovers());
    covers.addAll(getVariantVolumeCovers());
    return covers;
  }

  static Future<void> showVolume(
      {required BuildContext context,
      required Image image,
      required int volNumber,
      required String actionTitle,
      required Function action,
      bool isVariant = false}) async {
    switch (await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text('Title'),
            children: <Widget>[
              Container(padding: const EdgeInsets.all(6.0), child: image),
              const Divider(),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, 'action');
                },
                child: Text(actionTitle),
              ),
            ],
          );
        })) {
      case 'action':
        print("calling: action(context,$volNumber,$isVariant)");
        action(context, volNumber, isVariant);
        break;
      case null:
        break;
    }
  }

  /// Wraps the volume image inside a box shadow with tap detection
  static Widget volumeImageWrapper(
      {required BuildContext context,
      required Image image,
      required int volNumber,
      required String actionTitle,
      required Function action,
      bool isVariant = false}) {
    return GestureDetector(
      onTap: (() => showVolume(
          context: context,
          image: image,
          volNumber: volNumber,
          action: action,
          actionTitle: actionTitle,
          isVariant: isVariant)),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1.5,
              blurRadius: 3,
              offset: const Offset(0, 1),
            )
          ],
        ),
        alignment: Alignment.center,
        child:
            ClipRRect(borderRadius: BorderRadius.circular(4.0), child: image),
      ),
    );
  }

  /// Returns a Manga instance for the selected manga,
  static Future<Manga> getMangaByUUID({required String uuid}) async {
    final list = await Network.getMangaList();

    for (var manga in list) {
      if (manga['uuid'] == uuid) {
        return getMangaByDir(dir: manga['dir']);
      }
    }
    return emptyManga;
  }

  static Future<Manga> getMangaByDir({required String dir}) async {
    final response = await http.get(Uri.parse(Network.getMangaUrl(dir: dir)));

    if (response.statusCode == 200) {
      final jsStart = response.body.indexOf('{');
      final jsEnd = response.body.lastIndexOf('}') + 1;

      final js = jsonDecode(response.body.substring(jsStart, jsEnd));

      return Manga.fromJson(js);
    } else if (response.statusCode == 404) {
      throw ('getMangaByTitle($dir): 404 - Manga Not Found');
    } else {
      throw ('getMangaByTitle($dir): ${response.statusCode} - An error has occoured');
    }
  }
}

const Manga emptyManga = Manga(
    uuid: 'MangaNotFound',
    title: 'MangaNotFound',
    titleOriginal: 'MangaNotFound',
    genres: ['MangaNotFound'],
    story: 'MangaNotFound',
    design: 'MangaNotFound',
    editor: 'MangaNotFound',
    volumes: [-1],
    variants: [],
    imgDir: 'MangaNotFound',
    imgName: 'MangaNotFound');
