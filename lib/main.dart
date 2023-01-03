import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:mmdb_app/manga.dart';
import 'package:mmdb_app/oldMangaClass.dart';
import 'package:mmdb_app/network.dart';
import 'package:mmdb_app/user_library.dart';
import 'package:mmdb_app/volume.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MMDB',
      theme: ThemeData(
        /*dialogBackgroundColor: Colors.white,
        scaffoldBackgroundColor: Colors.black54,
        textTheme: const TextTheme(
            headline5: TextStyle(color: Colors.indigo),
            headline6: TextStyle(color: Colors.blueGrey)),*/
        primarySwatch: Colors.amber,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate, // Add this line
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English, no country code
        Locale('it', ''), // Italian, no country code
      ],
      home: const HomePage(),
    );
  }
}

//Theese classes are used to create the home page
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.startingPage = 0,
  });

  final int startingPage;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pages = <Widget>[];
  final _actions = <Widget>[];
  int currentPageIndex = 0;

  @override
  void initState() {
    super.initState();

    _pages.add(const OldDisplayPage());
    _pages.add(const OldLibraryPage());
    if (widget.startingPage > 0 && widget.startingPage < _pages.length) {
      currentPageIndex = widget.startingPage;
    }

    //_pages.clear();
    _pages.add(const DisplayPage());
    _pages.add(const LibraryPage());
    _actions.add(_getSettingsWidget());

    SharedPreferences.getInstance().then((db) {
      if (!db.getKeys().contains('userPreferencesUUID')) {
        db.setString('userPreferencesUUID', const Uuid().v4());
      }
    });
  }

  void _showSettings(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: ((context) => const SettingsPage())));
  }

  Widget _getSettingsWidget() {
    return IconButton(
        onPressed: (() => _showSettings(context)),
        icon: const Icon(Icons.settings));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.homePageTitle),
        actions: _actions,
      ),
      body: _pages[currentPageIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentPageIndex,
        onDestinationSelected: (int index) =>
            setState(() => currentPageIndex = index),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.view_carousel_rounded),
              label: AppLocalizations.of(context)!.mmdbLibraryLabel),
          NavigationDestination(
              icon: const Icon(Icons.menu_book_rounded),
              label: AppLocalizations.of(context)!.myMangasLabel),
          NavigationDestination(
              icon: const Icon(Icons.view_carousel_rounded),
              label: AppLocalizations.of(context)!.mmdbLibraryLabel),
          NavigationDestination(
              icon: const Icon(Icons.menu_book_rounded),
              label: AppLocalizations.of(context)!.myMangasLabel),
        ],
      ),
    );
  }
}

class DisplayPage extends StatefulWidget {
  const DisplayPage({super.key});

  @override
  State<DisplayPage> createState() => _DisplayPageState();
}

class _DisplayPageState extends State<DisplayPage> {
  final _widgets = <MangaListItem>[];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    FirebaseFirestore.instance
        .collection('mangas')
        .orderBy('mangaTitle')
        .withConverter(
            fromFirestore: Manga.fromFirestore,
            toFirestore: ((value, _) => value.toFirestore()))
        .get()
        .then((value) {
      for (var element in value.docs) {
        setState(() => _widgets.add(MangaListItem(
              manga: element.data(),
            )));
      }
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    _widgets.sort(
        ((MangaListItem a, MangaListItem b) => a.manga.compareTo(b.manga)));
    return _initialized
        ? SafeArea(
            child: ListView(children: _widgets),
          )
        : const LinearProgressIndicator();
  }
}

class MangaListItem extends StatelessWidget {
  MangaListItem({super.key, required this.manga});

  final GlobalKey _backgroundImageKey = GlobalKey();
  final Manga manga;

  void _openMangaPage(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: ((context) => MangaPage(
              manga: manga,
              selectedIndex: 0,
            ))));
  }

  Widget _buildBackground(BuildContext context) {
    return Flow(
      delegate: ParallaxFlowDelegate(
        scrollable: Scrollable.of(context)!,
        listItemContext: context,
        backgroundImageKey: _backgroundImageKey,
      ),
      children: [
        FutureBuilder(
            future: manga.getAllVolumesList(),
            builder: ((context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return snapshot.data?.first.getVolumeImage(
                    key: _backgroundImageKey,
                    fit: BoxFit.cover,
                  ) ??
                  emptyVolume.getVolumeImage();
            }))
      ],
    );
  }

  Widget _buildGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.6, 0.95],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleAndSubtitle() {
    return Positioned(
      left: 20,
      bottom: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            manga.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            manga.author != manga.mangaka
                ? '${manga.author} - ${manga.mangaka}'
                : manga.author,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GestureDetector(
            onTap: () {
              manga
                  .getAllVolumesList()
                  .then((value) => _openMangaPage(context));
            },
            child: Stack(
              children: [
                _buildBackground(context),
                _buildGradient(),
                _buildTitleAndSubtitle()
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// TODO remove once the new one is completed
class OldDisplayPage extends StatefulWidget {
  const OldDisplayPage({super.key});

  @override
  State<OldDisplayPage> createState() => _OldDisplayPageState();
}

class _OldDisplayPageState extends State<OldDisplayPage> {
  final _widgets = <OldMangaListItem>[];

  @override
  void initState() {
    super.initState();
    Network.getMangaList().then((list) {
      for (var mangaJS in list) {
        OldMangaClass.getMangaByDir(dir: mangaJS['dir']).then((manga) {
          setState(() => _widgets.add(OldMangaListItem(manga: manga)));
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _widgets.sort(((OldMangaListItem a, OldMangaListItem b) =>
        a.manga.compareTo(b.manga)));
    return SingleChildScrollView(
      child: Column(
        children: _widgets,
      ),
    );
  }
}

class OldMangaListItem extends StatelessWidget {
  OldMangaListItem({super.key, required this.manga});

  final GlobalKey _backgroundImageKey = GlobalKey();
  final OldMangaClass manga;

  void _openMangaPage(BuildContext context, OldMangaClass? mangaData) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: ((context) => OldMangaPage(
              manga: mangaData!,
              selectedIndex: 0,
            ))));
  }

  Widget _buildBackground(BuildContext context) {
    return Flow(
        delegate: ParallaxFlowDelegate(
            backgroundImageKey: _backgroundImageKey,
            listItemContext: context,
            scrollable: Scrollable.of(context)!),
        children: [
          CachedNetworkImage(
            imageUrl: Network.getMangaImageUrl(
                mangaImgDir: manga.imgDir!,
                mangaImgName: manga.imgName!,
                volumeNumber: '1'),
            key: _backgroundImageKey,
            fit: BoxFit.cover,
            placeholder: ((context, url) => const LinearProgressIndicator()),
          )
        ]);
  }

  Widget _buildGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.6, 0.95],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleAndSubtitle() {
    return Positioned(
      left: 20,
      bottom: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            manga.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            manga.story,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GestureDetector(
            onTap: () => _openMangaPage(context, manga),
            child: Stack(
              children: [
                _buildBackground(context),
                _buildGradient(),
                _buildTitleAndSubtitle()
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OldMangaPage extends StatefulWidget {
  const OldMangaPage(
      {super.key, required this.manga, required this.selectedIndex});

  final OldMangaClass manga;
  final int selectedIndex;
  @override
  State<OldMangaPage> createState() => _OldMangaPageState();
}

class _OldMangaPageState extends State<OldMangaPage> {
  void _addEveryVolumeToLibrary() {
    for (var vol in widget.manga.volumes!) {
      widget.manga.addVolumeToLibrary(context, vol, false, false);
    }
    for (var vars in widget.manga.variants!) {
      widget.manga.addVolumeToLibrary(context, vars, true, false);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            AppLocalizations.of(context)!.addedEveryVolumeToLibraryLabel)));
  }

  void _navigateTo(int index) {
    Navigator.of(context)
      ..pop()
      ..pop()
      ..push(MaterialPageRoute(
          builder: ((context) => HomePage(
                startingPage: index,
              ))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manga.title),
        actions: [
          IconButton(
              onPressed: _addEveryVolumeToLibrary,
              icon: const Icon(Icons.library_add_rounded)),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              ListTile(
                //titleOriginal
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.originalTitleLabel,
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.titleOriginal,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              ListTile(
                //story
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.storyByLabel,
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.story,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              ListTile(
                //designs
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.designsByLabel,
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.design,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              ListTile(
                //genres
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.genreLabel,
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.genres.join(', '),
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              ListTile(
                // Editor
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.editorLabel,
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.editor,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              widget.manga.getNormalVolumeCovers().isNotEmpty
                  ? Column(
                      // Volumes
                      children: <Widget>[
                        ListTile(
                          title: Text(
                              AppLocalizations.of(context)!
                                  .numberNormalVolumesLabel(
                                      widget.manga.volumes!.length),
                              style: Theme.of(context).textTheme.headline5),
                        ),
                        SizedBox(
                          height: 200,
                          child: GridView.count(
                            primary: false,
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 0),
                            crossAxisCount: 1,
                            mainAxisSpacing: 6,
                            scrollDirection: Axis.horizontal,
                            childAspectRatio: 1.5,
                            children: widget.manga
                                .getNormalVolumeCovers()
                                .asMap()
                                .entries
                                .map((e) => OldMangaClass.volumeImageWrapper(
                                      context: context,
                                      image: e.value,
                                      volNumber: widget.manga.volumes![e.key],
                                      action: widget.manga.addVolumeToLibrary,
                                      actionTitle: AppLocalizations.of(context)!
                                          .addToLibraryLabel,
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    )
                  : Divider(
                      color: Theme.of(context).backgroundColor,
                    ),
              widget.manga.getVariantVolumeCovers().isNotEmpty
                  ? Column(
                      // Variants
                      children: <Widget>[
                        ListTile(
                          title: Text(
                              AppLocalizations.of(context)!
                                  .numberVariantPublishedLabel(
                                      widget.manga.variants!.length),
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
                                .getVariantVolumeCovers()
                                .asMap()
                                .entries
                                .map((e) => OldMangaClass.volumeImageWrapper(
                                      context: context,
                                      image: e.value,
                                      volNumber: widget.manga.variants![e.key],
                                      action: widget.manga.addVolumeToLibrary,
                                      actionTitle: AppLocalizations.of(context)!
                                          .addToLibraryLabel,
                                      isVariant: true,
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    )
                  : Divider(
                      color: Theme.of(context).backgroundColor,
                    ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: (int index) => _navigateTo(index),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.view_carousel_rounded),
              label: AppLocalizations.of(context)!.mmdbLibraryLabel),
          NavigationDestination(
              icon: const Icon(Icons.menu_book_rounded),
              label: AppLocalizations.of(context)!.myMangasLabel)
        ],
      ),
    );
  }
}

// Theese classes are used to create each manga specific page
class MangaPage extends StatefulWidget {
  const MangaPage(
      {super.key, required this.manga, required this.selectedIndex});

  final Manga manga;
  final int selectedIndex;
  @override
  State<MangaPage> createState() => _MangaPageState();
}

class _MangaPageState extends State<MangaPage> {
  late final String _userUUID;

  void initState() {
    super.initState();
    SharedPreferences.getInstance().then(
      (value) {
        _userUUID = value.getString('userPreferencesUUID')!;
      },
    );
  }

  /*
  *  void _addEveryVolumeToLibrary() {
    for (var vol in widget.manga.volumes!) {
      widget.manga.addVolumeToLibrary(context, vol, false, false);
    }
    for (var vars in widget.manga.variants!) {
      widget.manga.addVolumeToLibrary(context, vars, true, false);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            AppLocalizations.of(context)!.addedEveryVolumeToLibraryLabel)));
  }
  */

  void _navigateTo(int index) {
    Navigator.of(context)
      ..pop()
      ..pop()
      ..push(MaterialPageRoute(
          builder: ((context) => HomePage(
                startingPage: index,
              ))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manga.title),
        actions: [
          IconButton(
              onPressed: () => print("_addEveryVolumeToLibrary"),
              icon: const Icon(Icons.library_add_rounded)),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              ListTile(
                //titleOriginal
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.originalTitleLabel,
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.titleOriginal,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              ListTile(
                //story
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.storyByLabel,
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.author,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              ListTile(
                //designs
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.designsByLabel,
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.mangaka,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              ListTile(
                //genres
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.genreLabel,
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.genre,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              ListTile(
                // Editor
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.editorLabel,
                      style: Theme.of(context).textTheme.headline5,
                    ),
                    Text(
                      widget.manga.editor,
                      style: Theme.of(context).textTheme.headline6,
                    )
                  ],
                ),
              ),
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              FutureBuilder(
                  //normals
                  future: widget.manga.getNormalVolumesList(),
                  builder: ((context, snapshot) {
                    if (snapshot.hasData) {
                      List<Volume> volumeList = snapshot.data ?? [];
                      if (volumeList.isEmpty) {
                        return Divider(
                            color: Theme.of(context).backgroundColor);
                      } else {
                        volumeList.sort();
                        return Column(
                          children: <Widget>[
                            ListTile(
                              title: Text(
                                  AppLocalizations.of(context)!
                                      .numberNormalVolumesLabel(
                                          volumeList.length),
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
                                children: volumeList
                                    .map((e) => e.volumeImageWrapper(
                                            context: context,
                                            action: e.showVolume,
                                            argv: [
                                              context,
                                              AppLocalizations.of(context)!
                                                  .addToLibraryLabel,
                                              e.addToLibrary,
                                              _userUUID,
                                            ]))
                                    .toList(),
                              ),
                            ),
                          ],
                        );
                      }
                    }
                    return const CircularProgressIndicator();
                  })),
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              FutureBuilder(
                  //variants
                  future: widget.manga.getVariantVolumesList(),
                  builder: ((context, snapshot) {
                    if (snapshot.hasData) {
                      List<Volume> volumeList = snapshot.data ?? [];
                      volumeList.sort();
                      if (volumeList.isEmpty) {
                        return Divider(
                            color: Theme.of(context).backgroundColor);
                      } else {
                        return Column(
                          children: <Widget>[
                            ListTile(
                              title: Text(
                                  AppLocalizations.of(context)!
                                      .numberVariantPublishedLabel(
                                          volumeList.length),
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
                                children: volumeList
                                    .map((e) => e.volumeImageWrapper(
                                            context: context,
                                            action: e.showVolume,
                                            argv: [
                                              context,
                                              AppLocalizations.of(context)!
                                                  .addToLibraryLabel,
                                              e.addToLibrary,
                                              _userUUID,
                                            ]))
                                    .toList(),
                              ),
                            ),
                          ],
                        );
                      }
                    }
                    return const CircularProgressIndicator();
                  })),
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: (int index) => _navigateTo(index),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.view_carousel_rounded),
              label: AppLocalizations.of(context)!.mmdbLibraryLabel),
          NavigationDestination(
              icon: const Icon(Icons.menu_book_rounded),
              label: AppLocalizations.of(context)!.myMangasLabel)
        ],
      ),
    );
  }
}

//imported from https://docs.flutter.dev/cookbook/effects/parallax-scrolling
class ParallaxFlowDelegate extends FlowDelegate {
  ParallaxFlowDelegate({
    required this.scrollable,
    required this.listItemContext,
    required this.backgroundImageKey,
  }) : super(repaint: scrollable.position);

  final ScrollableState scrollable;
  final BuildContext listItemContext;
  final GlobalKey backgroundImageKey;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    return BoxConstraints.tightFor(
      width: constraints.maxWidth,
    );
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    // Calculate the position of this list item within the viewport.
    final scrollableBox = scrollable.context.findRenderObject() as RenderBox;
    final listItemBox = listItemContext.findRenderObject() as RenderBox;
    final listItemOffset = listItemBox.localToGlobal(
        listItemBox.size.centerLeft(Offset.zero),
        ancestor: scrollableBox);

    // Determine the percent position of this list item within the
    // scrollable area.
    final viewportDimension = scrollable.position.viewportDimension;
    final scrollFraction =
        (listItemOffset.dy / viewportDimension).clamp(0.0, 1.0);

    // Calculate the vertical alignment of the background
    // based on the scroll percent.
    final verticalAlignment = Alignment(0.0, scrollFraction * 2 - 1);

    // Convert the background alignment into a pixel offset for
    // painting purposes.
    final backgroundSize =
        (backgroundImageKey.currentContext!.findRenderObject() as RenderBox)
            .size;
    final listItemSize = context.size;
    final childRect =
        verticalAlignment.inscribe(backgroundSize, Offset.zero & listItemSize);

    // Paint the background.
    context.paintChild(
      0,
      transform:
          Transform.translate(offset: Offset(0.0, childRect.top)).transform,
    );
  }

  @override
  bool shouldRepaint(ParallaxFlowDelegate oldDelegate) {
    return scrollable != oldDelegate.scrollable ||
        listItemContext != oldDelegate.listItemContext ||
        backgroundImageKey != oldDelegate.backgroundImageKey;
  }
}

class Parallax extends SingleChildRenderObjectWidget {
  const Parallax({
    super.key,
    required Widget background,
  }) : super(child: background);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderParallax(scrollable: Scrollable.of(context)!);
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderParallax renderObject) {
    renderObject.scrollable = Scrollable.of(context)!;
  }
}

class ParallaxParentData extends ContainerBoxParentData<RenderBox> {}

class RenderParallax extends RenderBox
    with RenderObjectWithChildMixin<RenderBox>, RenderProxyBoxMixin {
  RenderParallax({
    required ScrollableState scrollable,
  }) : _scrollable = scrollable;

  ScrollableState _scrollable;

  ScrollableState get scrollable => _scrollable;

  set scrollable(ScrollableState value) {
    if (value != _scrollable) {
      if (attached) {
        _scrollable.position.removeListener(markNeedsLayout);
      }
      _scrollable = value;
      if (attached) {
        _scrollable.position.addListener(markNeedsLayout);
      }
    }
  }

  @override
  void attach(covariant PipelineOwner owner) {
    super.attach(owner);
    _scrollable.position.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _scrollable.position.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! ParallaxParentData) {
      child.parentData = ParallaxParentData();
    }
  }

  @override
  void performLayout() {
    size = constraints.biggest;

    // Force the background to take up all available width
    // and then scale its height based on the image's aspect ratio.
    final background = child!;
    final backgroundImageConstraints =
        BoxConstraints.tightFor(width: size.width);
    background.layout(backgroundImageConstraints, parentUsesSize: true);

    // Set the background's local offset, which is zero.
    (background.parentData as ParallaxParentData).offset = Offset.zero;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Get the size of the scrollable area.
    final viewportDimension = scrollable.position.viewportDimension;

    // Calculate the global position of this list item.
    final scrollableBox = scrollable.context.findRenderObject() as RenderBox;
    final backgroundOffset =
        localToGlobal(size.centerLeft(Offset.zero), ancestor: scrollableBox);

    // Determine the percent position of this list item within the
    // scrollable area.
    final scrollFraction =
        (backgroundOffset.dy / viewportDimension).clamp(0.0, 1.0);

    // Calculate the vertical alignment of the background
    // based on the scroll percent.
    final verticalAlignment = Alignment(0.0, scrollFraction * 2 - 1);

    // Convert the background alignment into a pixel offset for
    // painting purposes.
    final background = child!;
    final backgroundSize = background.size;
    final listItemSize = size;
    final childRect =
        verticalAlignment.inscribe(backgroundSize, Offset.zero & listItemSize);

    // Paint the background.
    context.paintChild(
        background,
        (background.parentData as ParallaxParentData).offset +
            offset +
            Offset(0.0, childRect.top));
  }
}
// end of imported https://docs.flutter.dev/cookbook/effects/parallax-scrolling

// These Classes are used to create the library page

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final String? _uuid;
  late final UserLibrary _userLibrary;
  bool _restored = false;

  void _openMangaPage(BuildContext context, Manga manga) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: ((context) => MangaPage(
              manga: manga,
              selectedIndex: 0,
            ))));
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((sp) {
      _uuid = sp.getString("userPreferencesUUID");
      setState(() {
        _restored = true;
        print("LibraryPage.initState(): uuid = $_uuid ");
        print("LibraryPage.initState():  restored = $_restored");
      });
    });
  }

  Future<List<Manga>> getSavedMangasByUser() async {
    List<Manga> savedMangas = <Manga>[];
    if (_uuid == null) return Future.sync(() => savedMangas);

    final db = FirebaseFirestore.instance;
    final res = await db.collection('users').doc(_uuid).get();

    if (!res.exists) return savedMangas;

    for (var uuid in res.data()?['userMangaUUIDList'] ?? []) {
      savedMangas.add(await Manga.fromUUID(uuid));
    }

    return savedMangas;
  }

  Future<List<Volume>> getSavedVolumesByUserAndManga(Manga manga) async {
    final List<Volume> volumes = <Volume>[];

    var db = FirebaseFirestore.instance;
    final query = await db.collection('users').doc(_uuid).get();

    if (!query.exists) return volumes;

    return volumes;
  }

  Future<SplayTreeMap<Manga, List<Volume>>> getSavedVolumesMapByUser() async {
    final SplayTreeMap<Manga, List<Volume>> savedVolumes = SplayTreeMap();

    final List<Manga> savedMangas = await getSavedMangasByUser();

    if (savedMangas.isEmpty) {
      return savedVolumes;
    }

    final db = FirebaseFirestore.instance;
    var res = await db.collection('users').doc(_uuid).get();

    if (!res.exists) {
      return savedVolumes;
    }

    final volumesUUIDs = res.data()?['userVolumeUUIDList'] ?? [];

    final List<Volume> savedVolumesList = <Volume>[];
    for (var uuid in volumesUUIDs) {
      var value = await Volume.getVolumeByUUID(uuid);
      if (value.uuid != emptyVolume.uuid) {
        savedVolumesList.add(value);
      }
    }
    for (Manga manga in savedMangas) {
      var v = <Volume>[];
      for (var vol in savedVolumesList) {
        if (vol.mangaUUID == manga.uuid) v.add(vol);
      }
      savedVolumes.addAll({manga: v});
    }
    return savedVolumes;
  }

  Widget _getChildren(Manga manga, Future<List<Volume>> volumes) {
    print("LibraryPage.getChildren: manga = ${manga.title} ");

    return FutureBuilder(
      future: volumes,
      builder: ((context, snapshot) {
        print(
            "LibraryPage.getChildren: snapshot.hasData = ${snapshot.hasData}");
        return Column(
          children: <Widget>[
            SizedBox(
              height: 45,
              child: TextButton(
                onLongPress: () =>
                    print("_openMangaMenu(manga, savedVolumesList)"),
                onPressed: () => _openMangaPage(context, manga),
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
                  children: snapshot.hasData
                      ? snapshot.data!
                          .map((vol) => vol.volumeImageWrapper(
                                context: context,
                                argv: [
                                  context,
                                  AppLocalizations.of(context)!
                                      .removeFromLibraryLabel,
                                  print
                                ],
                                action: vol.showVolume,
                              ))
                          .toList()
                      : [const CircularProgressIndicator()]),
            )
          ],
        );
      }),
    );
  }

  Future<UserLibrary> _getUserLibrary() async {
    print("LibraryPage.getUserLibrary(): start");
    var db = FirebaseFirestore.instance;
    final query = await db
        .collection('users')
        .doc(_uuid)
        .withConverter(
            fromFirestore: UserLibrary.fromFirestore,
            toFirestore: (ul, _) => ul.toFirestore())
        .get();
    print("LibraryPage.getUserLibrary:  query.exist = ${query.exists}");
    print("LibraryPage.getUserLibrary:  Done!");
    if (!query.exists) {
      final ul = UserLibrary.emptyLibrary(_uuid);
      db
          .collection('users')
          .doc(_uuid)
          .withConverter(
              fromFirestore: UserLibrary.fromFirestore,
              toFirestore: (ul, _) => ul.toFirestore())
          .set(ul);
      return ul;
    }
    return query.data()!;
  }

  Future<List<Widget>> _getBody() async {
    print("LibraryPage.getBody(): Start! ");
    List<Widget> children = <Widget>[];
    List<Manga> mangas = await _userLibrary.getSavedMangas();
    print(
        "LibraryPage.getBody(): mangas = ${mangas.map((e) => e.title).toList().toString()} ");
    for (var manga in mangas) {
      children.add(
          _getChildren(manga, _userLibrary.getSavedVolumesForManga(manga)));
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    if (!_restored) {
      print("LibraryPage.build(): restored = $_restored");
      return const LinearProgressIndicator();
    }
    print("LibraryPage.build(): restored = $_restored");
    return SafeArea(
      child: FutureBuilder(
        future: _getUserLibrary(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print(
                "LibraryPage.build(): _getUserLibrary.error = ${snapshot.error.toString()} ");
            return Center(child: Text(snapshot.error.toString()));
          } else if (snapshot.hasData) {
            _userLibrary = snapshot.data!;
            print(
                "LibraryPage.build(): _userLibrary.empty = ${_userLibrary.isEmpty()}");

            if (_userLibrary.isEmpty()) {
              return Center(
                  child: Text(AppLocalizations.of(context)!.noSavedMangaLabel));
            }

            return FutureBuilder(
              future: _getBody(),
              builder: ((context, snapshot) {
                print("LibraryPage.build(): inFuturebuilder");
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                print(
                    "LibraryPage.build(): snapshot.hasData = ${snapshot.hasData}");
                return SingleChildScrollView(
                  child: Column(children: snapshot.data!),
                );
              }),
            );
          } else {
            return const LinearProgressIndicator();
          }
        },
      ),
    );

    /*
    return SafeArea(
      child: FutureBuilder(
        future: getSavedVolumesMapByUser(),
        builder: ((context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          List<Widget> children = <Widget>[];

          if (snapshot.data!.isEmpty) {
            return Center(
                child: Text(AppLocalizations.of(context)!.noSavedMangaLabel));
          }

          for (var manga in snapshot.data!.keys) {
            var volumes = snapshot.data![manga]!;
            children.add(_getChildren(manga, volumes));
          }

          return SingleChildScrollView(
            child: Column(
              children: children,
            ),
          );
        }),
      ),
    );
    */
  }
}

// TODO remove once the migration to firebase is completed
class OldLibraryPage extends StatefulWidget {
  const OldLibraryPage({super.key});

  @override
  State<OldLibraryPage> createState() => _OldLibraryPageState();
}

class _OldLibraryPageState extends State<OldLibraryPage> {
  late final SharedPreferences _db;
  late final List<String> _mangaList;
  late final SplayTreeMap<OldMangaClass, List<int>> _volumes = SplayTreeMap();
  bool _restored = false;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((db) {
      _db = db;
      _restorePreferences().then((volumes) {
        _restored = true;
        setState(() => _volumes.addEntries(volumes.entries));
      });
    });
  }

  Future<Map<OldMangaClass, List<int>>> _restorePreferences() async {
    final Map<OldMangaClass, List<int>> volumes = <OldMangaClass, List<int>>{};
    //First get the list of saved manga:
    _mangaList = _db.getStringList('savedMangasUUID') ?? [];
    _mangaList.sort();

    //then iterate for each manga and retrieve saved volumes
    for (var mangaUUID in _mangaList) {
      final vols =
          _db.getStringList(mangaUUID)?.map((e) => int.parse(e)).toList() ?? [];
      vols.sort(((a, b) => a.abs().compareTo(b.abs())));
      final manga = await OldMangaClass.getMangaByUUID(uuid: mangaUUID);
      volumes.addEntries({manga: vols}.entries);
    }
    SplayTreeMap.from(volumes,
        ((OldMangaClass key1, OldMangaClass key2) => key1.compareTo(key2)));
    return volumes;
  }

  Future<void> _removeEveryVolume(
      OldMangaClass manga, List<int> savedVolumes) async {
    for (var vol in savedVolumes) {
      manga.removeVolumeFromLibrary(context, vol.abs(), vol < 0, false);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.removedEveryVolumeLabel)));
  }

  void _openMangaMenu(OldMangaClass manga, List<int> savedVolumeList) async {
    switch (await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Text(manga.title),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, 'rem');
                },
                child: const Text('Remove every volume.'),
              ),
            ],
          );
        })) {
      case 'rem':
        _removeEveryVolume(manga, savedVolumeList).then((value) {
          setState(() {});
        });
        break;
      case null:
        setState(() {});
        break;
    }
  }

  List<Widget> _getChildrens() {
    List<Widget> children = <Widget>[];

    _volumes.forEach((manga, savedVolumesList) {
      children.add(Column(children: <Widget>[
        SizedBox(
          height: 45,
          child: TextButton(
            onLongPress: () => _openMangaMenu(manga, savedVolumesList),
            onPressed: () => _openMangaPage(context, manga),
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
                  .map((vol) => OldMangaClass.volumeImageWrapper(
                      context: context,
                      image: manga.getVolumeCover(
                          volumeNumber: vol.abs(), isVariant: (vol < 0)),
                      volNumber: vol.abs(),
                      actionTitle:
                          AppLocalizations.of(context)!.removeFromLibraryLabel,
                      action: manga.removeVolumeFromLibrary,
                      isVariant: vol < 0))
                  .toList()),
        ),
      ]));
    });

    return children;
  }

  void _openMangaPage(BuildContext context, OldMangaClass? mangaData) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: ((context) => OldMangaPage(
              manga: mangaData!,
              selectedIndex: 1,
            ))));
  }

  @override
  Widget build(BuildContext context) {
    if (!_restored) {
      return const LinearProgressIndicator();
    }
    if (_volumes.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.noSavedMangaLabel),
      );
    }
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: _getChildrens(),
        ),
      ),
    );
  }
}

// These classes are used to open settings

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _saveSettings() {}

  Widget _getLocaleSettingsEntry() {
    return ListTile(
      title: Text(
        AppLocalizations.of(context)!.selectedLanguageLabel,
        style: Theme.of(context).textTheme.headline6,
      ),
      trailing: TextButton(
        onPressed: (() {
          return;
        }),
        child: Text(AppLocalizations.of(context)!.localeFlagLabel),
      ),
    );
  }

  List<Widget> _getSettingsWidget() {
    final widgets = <Widget>[];

    widgets.add(_getLocaleSettingsEntry());
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final bodyWidgets = _getSettingsWidget();
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settingsLabel)),
      body: SafeArea(
        child: ListView.separated(
            padding: const EdgeInsets.all(8.0),
            itemBuilder: ((context, index) => bodyWidgets[index]),
            separatorBuilder: ((context, index) =>
                Divider(color: Theme.of(context).backgroundColor)),
            itemCount: bodyWidgets.length),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _saveSettings(),
        child: const Icon(Icons.save),
      ),
    );
  }
}
