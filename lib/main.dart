import 'dart:collection';
import 'package:flutter/rendering.dart';
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
        /*dialogBackgroundColor: Colors.white,
        scaffoldBackgroundColor: Colors.black54,
        textTheme: const TextTheme(
            headline5: TextStyle(color: Colors.indigo),
            headline6: TextStyle(color: Colors.blueGrey)),*/
        primarySwatch: Colors.amber,
      ),
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

  final String homePageTitle = "Welcome to MMDB!";
  final int startingPage;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pages = <Widget>[];
  int currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pages.add(const DisplayPage());
    _pages.add(const LibraryPage());
    if (widget.startingPage > 0 && widget.startingPage < _pages.length) {
      currentPageIndex = widget.startingPage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.homePageTitle),
      ),
      body: _pages[currentPageIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentPageIndex,
        onDestinationSelected: (int index) =>
            setState(() => currentPageIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.view_carousel_rounded), label: 'MMDB Library'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_rounded), label: 'My mangas')
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

  @override
  void initState() {
    super.initState();
    Network.getMangaList().then((list) {
      for (var mangaJS in list) {
        Manga.getMangaByDir(dir: mangaJS['dir']).then((manga) {
          setState(() => _widgets.add(MangaListItem(manga: manga)));
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _widgets.sort(
        ((MangaListItem a, MangaListItem b) => a.manga.compareTo(b.manga)));
    return SingleChildScrollView(
      child: Column(
        children: _widgets,
      ),
    );
  }
}

class MangaListItem extends StatelessWidget {
  MangaListItem({super.key, required this.manga});

  final GlobalKey _backgroundImageKey = GlobalKey();
  final Manga manga;

  void _openMangaPage(BuildContext context, Manga? mangaData) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: ((context) => MangaPage(
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
          Image.network(
            Network.getMangaImageUrl(
                mangaImgDir: manga.imgDir,
                mangaImgName: manga.imgName,
                volumeNumber: '1'),
            key: _backgroundImageKey,
            fit: BoxFit.cover,
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
  void _addEveryVolumeToLibrary() {
    for (var vol in widget.manga.volumes) {
      widget.manga.addVolumeToLibrary(context, vol, false, false);
    }
    for (var vars in widget.manga.variants) {
      widget.manga.addVolumeToLibrary(context, vars, true, false);
    }
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Added every volume to library")));
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
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              ListTile(
                //story
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              ListTile(
                //designs
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              ListTile(
                //genres
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
              Divider(
                color: Theme.of(context).backgroundColor,
              ),
              ListTile(
                // Editor
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
              Divider(
                color: Theme.of(context).backgroundColor,
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
                                .map((e) => Manga.volumeImageWrapper(
                                      context: context,
                                      image: e.value,
                                      volNumber: widget.manga.volumes[e.key],
                                      action: widget.manga.addVolumeToLibrary,
                                      actionTitle: 'Add to Library',
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
                              '${widget.manga.variants.length} special edition published: ',
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
                                .map((e) => Manga.volumeImageWrapper(
                                      context: context,
                                      image: e.value,
                                      volNumber: widget.manga.variants[e.key],
                                      action: widget.manga.addVolumeToLibrary,
                                      actionTitle: 'Add to Library',
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
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.view_carousel_rounded), label: 'MMDB Library'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_rounded), label: 'My mangas')
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
  late final SharedPreferences _db;
  late final List<String> _mangaList;
  late final SplayTreeMap<Manga, List<int>> _volumes = SplayTreeMap();
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

  Future<Map<Manga, List<int>>> _restorePreferences() async {
    final Map<Manga, List<int>> volumes = <Manga, List<int>>{};
    //First get the list of saved manga:
    _mangaList = _db.getStringList('savedMangasUUID') ?? [];
    _mangaList.sort();

    //then iterate for each manga and retrieve saved volumes
    for (var mangaUUID in _mangaList) {
      final vols =
          _db.getStringList(mangaUUID)?.map((e) => int.parse(e)).toList() ?? [];
      vols.sort(((a, b) => a.abs().compareTo(b.abs())));
      final manga = await Manga.getMangaByUUID(uuid: mangaUUID);
      volumes.addEntries({manga: vols}.entries);
    }
    SplayTreeMap.from(
        volumes, ((Manga key1, Manga key2) => key1.compareTo(key2)));
    return volumes;
  }

  Future<void> _removeEveryVolume(Manga manga, List<int> savedVolumes) async {
    for (var vol in savedVolumes) {
      manga.removeVolumeFromLibrary(context, vol.abs(), vol < 0, false);
    }
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Removed every volume from library")));
  }

  void _openMangaMenu(Manga manga, List<int> savedVolumeList) async {
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
                  .map((vol) => Manga.volumeImageWrapper(
                      context: context,
                      image: manga.getVolumeCover(
                          volumeNumber: vol.abs(), isVariant: (vol < 0)),
                      volNumber: vol.abs(),
                      actionTitle: "Remove from library",
                      action: manga.removeVolumeFromLibrary,
                      isVariant: vol < 0))
                  .toList()),
        ),
      ]));
    });

    return children;
  }

  void _openMangaPage(BuildContext context, Manga? mangaData) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: ((context) => MangaPage(
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
      return const Center(
        child: Text("You have no saved manga"),
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
