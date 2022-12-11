import 'dart:core';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Network {
  static const String proto = "http";
  static const String githubPagesDomain = "kr1bas.github.io";
  static const String githubPagesSubDomain = "mmdb";
  static const String githubPagesURL =
      "$proto://$githubPagesDomain/$githubPagesSubDomain";
  static const String githubPagesMangaList = "$githubPagesURL/ids.html";

  static Future<List<dynamic>> getMangaList() async {
    final response = await http.get(Uri.parse(githubPagesMangaList));
    if (response.statusCode == 200) {
      final js = jsonDecode(response.body.substring(
          response.body.indexOf('{'), response.body.lastIndexOf('}') + 1));

      return js['list'];
    } else {
      return [];
    }
  }

  static String getMangaUrl({required String dir}) {
    return "$githubPagesURL/mangas/$dir.html";
  }

  static String getMangaImageUrl(
      {required String mangaImgDir,
      required String mangaImgName,
      required String volumeNumber,
      bool isVariant = false}) {
    return "$githubPagesURL/img/$mangaImgDir/$mangaImgName-$volumeNumber${isVariant ? '-variant' : ''}.jpg";
  }
}
