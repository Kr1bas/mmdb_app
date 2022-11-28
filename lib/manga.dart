import 'dart:convert';

import 'package:http/http.dart' as html;
import 'package:flutter/material.dart';
import 'package:mmdb_app/network.dart';

class Manga {
  const Manga(
      {required this.title,
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
    final js = jsonEncode(this);
    print(js);
    return js;
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
      {required BuildContext context, required Image image}) async {
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
                  Navigator.pop(context, 'Add');
                },
                child: const Text('Add to library'),
              ),
            ],
          );
        })) {
      case 'Add':
        print("ADD");
        break;
      case null:
        print("Dismiss");
        break;
    }
  }

  /// Wraps the volume image inside a box shadow with tap detection
  static Widget volumeImageWrapper(
      {required BuildContext context, required Image image}) {
    return GestureDetector(
      onTap: (() => showVolume(context: context, image: image)),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 1),
            )
          ],
        ),
        alignment: Alignment.center,
        child: image,
      ),
    );
  }

  /// Returns a Manga instance for the selected manga,
  static Future<Manga> getMangaByTitle({required String title}) async {
    final response =
        await html.get(Uri.parse(Network.getMangaUrl(mangaTitle: title)));

    if (response.statusCode == 200) {
      final jsStart = response.body.indexOf('{');
      final jsEnd = response.body.lastIndexOf('}') + 1;

      final js = jsonDecode(response.body.substring(jsStart, jsEnd));

      return Manga.fromJson(js);
    } else if (response.statusCode == 404) {
      throw ('getMangaByTitle($title): 404 - Manga Not Found');
    } else {
      throw ('getMangaByTitle($title): ${response.statusCode} - An error has occoured');
    }
  }
}

const Manga emptyManga = Manga(
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
