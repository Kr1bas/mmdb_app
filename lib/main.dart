import 'dart:developer';
import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:mmdb_app/manga.dart';
import 'package:mmdb_app/network.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MMDB',
      theme: ThemeData(
        primaryColorDark: Colors.blue,
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final SharedPreferences _db;
  late final List<String> _mangaList;
  final Map<Manga, List<int>> _volumes = <Manga, List<int>>{};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((db) {
      _db = db;
      _restorePreferences().then(
          (volumes) => setState(() => _volumes.addEntries(volumes.entries)));
    });
  }

  Future<Map<Manga, List<int>>> _restorePreferences() async {
    final Map<Manga, List<int>> volumes = <Manga, List<int>>{};
    //First get the list of saved manga:
    _mangaList = _db.getStringList('savedMangasUUID') ?? [];
    //then iterate for each manga and retrieve saved volumes
    for (var mangaUUID in _mangaList) {
      final vols =
          _db.getStringList(mangaUUID)?.map((e) => int.parse(e)).toList() ?? [];
      final manga = await Manga.getMangaByUUID(uuid: mangaUUID);
      volumes.addEntries({manga: vols}.entries);
    }
    return volumes;
  }

  List<Widget> _getChildrens() {
    List<Widget> children = <Widget>[];

    _volumes.forEach((manga, savedVolumesList) {
      children.add(Column(children: <Widget>[
        SizedBox(
          height: 45,
          child: TextButton(
            onPressed: () => SnackBar(content: Text(manga.title)),
            child: ListTile(
              title: Text(
                manga.title,
                style: Theme.of(context).textTheme.headline5,
              ),
              trailing: const Icon(Icons.open_in_new),
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: GridView.count(
              primary: false,
              padding: const EdgeInsets.all(6),
              crossAxisCount: 1,
              mainAxisSpacing: 6,
              scrollDirection: Axis.horizontal,
              childAspectRatio: 1.5,
              children: savedVolumesList
                  .map((vol) => Manga.volumeImageWrapper(
                      context: context,
                      image: manga.getVolumeCover(volumeNumber: vol),
                      volNumber: vol,
                      actionTitle: "Remove from library",
                      action: manga.removeVolumeFromLibrary))
                  .toList()),
        ),
      ]));
    });

    return children;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('My library'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: _getChildrens(),
            ),
          ),
        ));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  final String homePageTitle = "Welcome to MMDB!";
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _widgets = <Widget>[];

  void _showSaved(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: ((context) => const LibraryPage())));
  }

  @override
  void initState() {
    super.initState();
    Network.getMangaList().then((list) {
      for (var manga in list) {
        setState(() {
          _widgets.add(VolumesList(uuid: manga['uuid'], dir: manga['dir']));
          _widgets.add(const Divider());
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.homePageTitle),
          actions: [
            IconButton(
                onPressed: () => _showSaved(context),
                icon: const Icon(Icons.list))
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: _widgets,
            ),
          ),
        ));
  }
}

class VolumesList extends StatefulWidget {
  const VolumesList({super.key, required this.uuid, required this.dir});

  final String uuid;
  final String dir;
  @override
  State<VolumesList> createState() => _VolumesListState();
}

class _VolumesListState extends State<VolumesList> {
  late final Future<Manga> _manga;
  bool initalized = false;

  @override
  void initState() {
    super.initState();
    _manga = Manga.getMangaByDir(dir: widget.dir);
  }

  void _openMangaPage(BuildContext context, Manga? mangaData) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: ((context) => MangaPage(
              manga: mangaData!,
            ))));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Manga>(
      future: _manga,
      builder: ((context, mangaData) {
        if (mangaData.hasData) {
          return Column(
            children: <Widget>[
              SizedBox(
                height: 45,
                child: TextButton(
                  onPressed: () => _openMangaPage(context, mangaData.data),
                  child: ListTile(
                    title: Text(
                      mangaData.data!.title,
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    trailing: const Icon(Icons.open_in_new),
                  ),
                ),
              ),
              SizedBox(
                height: 200,
                child: GridView.count(
                  primary: false,
                  padding: const EdgeInsets.all(6),
                  crossAxisCount: 1,
                  mainAxisSpacing: 6,
                  scrollDirection: Axis.horizontal,
                  childAspectRatio: 1.5,
                  children: mangaData.data!
                      .getAllVolumeCovers()
                      .asMap()
                      .entries
                      .map((e) => Manga.volumeImageWrapper(
                            context: context,
                            image: e.value,
                            volNumber: e.key + 1,
                            action: mangaData.data!.addVolumeToLibrary,
                            actionTitle: 'Add to Library',
                          ))
                      .toList(),
                ),
              ),
            ],
          );
        } else if (mangaData.hasError) {
          log("build(${widget.uuid}): error = ${mangaData.error}");
          return Column(
            children: <Widget>[
              ListTile(
                  title: Text(
                emptyManga.title,
                style: Theme.of(context).textTheme.headline5,
              )),
              SizedBox(
                height: 200,
                child: GridView.count(
                  primary: false,
                  padding: const EdgeInsets.all(6),
                  crossAxisCount: 1,
                  mainAxisSpacing: 6,
                  scrollDirection: Axis.horizontal,
                  childAspectRatio: 1.5,
                  children: emptyManga.getAllVolumeCovers(),
                ),
              ),
            ],
          );
        }

        return const CircularProgressIndicator();
      }),
    );
  }
}

class MangaPage extends StatefulWidget {
  const MangaPage({super.key, required this.manga});

  final Manga manga;

  @override
  State<MangaPage> createState() => _MangaPageState();
}

class _MangaPageState extends State<MangaPage> {
  void nullFunction() {
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.manga.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              ListTile(
                //titleOriginal
                title: Row(
                  children: [
                    Text(
                      'Japanese Title:  ',
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.titleOriginal,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              ListTile(
                //story
                title: Row(
                  children: [
                    Text(
                      'Story by  ',
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.story,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              ListTile(
                //designs
                title: Row(
                  children: [
                    Text(
                      'Designs by  ',
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.design,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              ListTile(
                //genres
                title: Row(
                  children: [
                    Text(
                      'Genre:  ',
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.genres.join(', '),
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              ListTile(
                // Editor
                title: Row(
                  children: [
                    Text(
                      'Published by  ',
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.editor,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              widget.manga.getNormalVolumeCovers().isNotEmpty
                  ? Column(
                      // Volumes
                      children: <Widget>[
                        ListTile(
                          title: Text(
                              '${widget.manga.volumes.length} volumes published: ',
                              style: Theme.of(context).textTheme.headline5),
                        ),
                        SizedBox(
                          height: 200,
                          child: GridView.count(
                            primary: false,
                            padding: const EdgeInsets.all(6),
                            crossAxisCount: 1,
                            mainAxisSpacing: 6,
                            scrollDirection: Axis.horizontal,
                            childAspectRatio: 1.5,
                            children: widget.manga
                                .getNormalVolumeCovers()
                                .asMap()
                                .entries
                                .map((e) => Manga.volumeImageWrapper(
                                      context: context,
                                      image: e.value,
                                      volNumber: e.key + 1,
                                      action: nullFunction,
                                      actionTitle: 'Add to Library',
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    )
                  : const Divider(),
              widget.manga.getVariantVolumeCovers().isNotEmpty
                  ? Column(
                      // Variants
                      children: <Widget>[
                        ListTile(
                          title: Text(
                              '${widget.manga.variants.length} special edition published: ',
                              style: Theme.of(context).textTheme.headline5),
                        ),
                        SizedBox(
                          height: 180,
                          child: GridView.count(
                            primary: false,
                            padding: const EdgeInsets.all(6),
                            crossAxisCount: 1,
                            mainAxisSpacing: 6,
                            scrollDirection: Axis.horizontal,
                            childAspectRatio: 1.5,
                            children: widget.manga
                                .getVariantVolumeCovers()
                                .asMap()
                                .entries
                                .map((e) => Manga.volumeImageWrapper(
                                      context: context,
                                      image: e.value,
                                      volNumber: e.key + 1,
                                      action: nullFunction,
                                      actionTitle: 'Add to Library',
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    )
                  : const Divider(
                      color: Colors.white,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

//TODO Remove
class SavedRandomPairs extends StatefulWidget {
  const SavedRandomPairs({super.key, required this.savedPairs});

  final List<String> savedPairs;
  final String title = "Saved";
  @override
  State<SavedRandomPairs> createState() => _SavedRandomPairsState();
}

class _SavedRandomPairsState extends State<SavedRandomPairs> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: ListView.separated(
          itemCount: widget.savedPairs.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: ((context, index) => ListTile(
                title: Text(
                  widget.savedPairs[index],
                  style: Theme.of(context).textTheme.headline4,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () =>
                      setState(() => widget.savedPairs.removeAt(index)),
                ),
              )),
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.of(context).pop(widget.savedPairs),
          child: const Icon(Icons.save)),
    );
  }
}

class RandomPairs extends StatefulWidget {
  const RandomPairs({
    super.key,
  });

  //final int count;
  final String title = "Random generated names";
  @override
  State<RandomPairs> createState() => _RandomPairsState();
}

class _RandomPairsState extends State<RandomPairs> {
  final _generatedNames = <String>[];
  final _favouritedNames = <String>[];
  late final SharedPreferences _db;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((SharedPreferences db) {
      _db = db;
      setState(() {
        _generatedNames.addAll(_db.getStringList('generated') ?? []);
        _favouritedNames.addAll(_db.getStringList('saved') ?? []);
      });
    });
  }

  void _incrementCounter() {
    setState(() {
      generateWordPairs()
          .take(1)
          .forEach((element) => _generatedNames.add(element.asPascalCase));
      _db.setStringList('generated', _generatedNames);
    });
  }

  void _showSaved(BuildContext context) async {
    final List<String> result = await Navigator.of(context).push(
        MaterialPageRoute(
            builder: ((context) =>
                SavedRandomPairs(savedPairs: _favouritedNames))));

    _favouritedNames.removeWhere((element) => !result.contains(element));
    _db.setStringList('saved', _favouritedNames);
    _db.setStringList('generated', _generatedNames);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
              onPressed: () => _showSaved(context),
              icon: const Icon(Icons.list))
        ],
      ),
      body: Center(
        child: ListView.separated(
          itemBuilder: (context, i) => ListTile(
              title: Text(
                _generatedNames[i],
                style: Theme.of(context).textTheme.headline4,
              ),
              trailing: IconButton(
                icon: Icon(
                  _favouritedNames.contains(_generatedNames[i])
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: _favouritedNames.contains(_generatedNames[i])
                      ? Colors.red
                      : null,
                  semanticLabel: _favouritedNames.contains(_generatedNames[i])
                      ? "Remove from saved"
                      : "Save",
                ),
                onPressed: (() => setState(() {
                      _favouritedNames.contains(_generatedNames[i])
                          ? _favouritedNames.remove(_generatedNames[i])
                          : _favouritedNames.add(_generatedNames[i]);
                    })),
              ),
              leading: Container(
                alignment: Alignment.center,
                height: 256,
                width: 64,
                child: Image.network(
                    "https://kr1bas.github.io/mmdb/img/mashle/mashle-${i + 1}.jpg"),
              )),
          separatorBuilder: (c, i) => const Divider(),
          itemCount: _generatedNames.length,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        hoverElevation: 12,
        child: const Icon(Icons.add),
      ),
    );
  }
}
