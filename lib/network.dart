import 'dart:core';

class Network {
  static const String proto = "https";
  static const String githubPagesDomain = "kr1bas.github.io";
  static const String githubPagesSubDomain = "mmdb";
  static const String githubPagesURL =
      "$proto://$githubPagesDomain/$githubPagesSubDomain";

  static Future<List<String>> getMangaList() async {
    // TODO add api interaction
    return ['mashle', '20th-century-boys', 'tokyo-revengers'];
  }

  static String getMangaUrl({required String mangaTitle}) {
    return "$githubPagesURL/mangas/$mangaTitle.html";
  }

  static String getMangaImageUrl(
      {required String mangaImgDir,
      required String mangaImgName,
      required String volumeNumber,
      bool isVariant = false}) {
    return "$githubPagesURL/img/$mangaImgDir/$mangaImgName-$volumeNumber${isVariant ? '-variant' : ''}.jpg";
  }
}
