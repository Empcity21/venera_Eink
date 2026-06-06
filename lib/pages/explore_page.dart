import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/global_state.dart';
import 'package:venera/foundation/res.dart';
import 'package:venera/pages/comic_source_page.dart';
import 'package:venera/pages/settings/settings_page.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/translations.dart';
import 'package:venera/utils/volume.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<ExplorePage> {
  late TabController controller;

  bool showFB = true;

  double location = 0;

  late List<String> pages;

  void onSettingsChanged() {
    var explorePages = List<String>.from(appdata.settings["explore_pages"]);
    var all = ComicSource.all()
        .map((e) => e.explorePages)
        .expand((e) => e.map((e) => e.title))
        .toList();
    explorePages = explorePages.where((e) => all.contains(e)).toList();
    if (!pages.isEqualTo(explorePages)) {
      setState(() {
        pages = explorePages;
        controller = TabController(
          length: pages.length,
          vsync: this,
        );
      });
    }
  }

  void onNaviItemTapped(int index) {
    if (index == 2) {
      int page = controller.index;
      String currentPageId = pages[page];
      GlobalState.find<_SingleExplorePageState>(currentPageId).toTop();
    }
  }

  void addPage() {
    showPopUpWidget(App.rootContext, setExplorePagesWidget());
  }

  NaviPaneState? naviPane;

  @override
  void initState() {
    pages = List<String>.from(appdata.settings["explore_pages"]);
    var all = ComicSource.all()
        .map((e) => e.explorePages)
        .expand((e) => e.map((e) => e.title))
        .toList();
    pages = pages.where((e) => all.contains(e)).toList();
    controller = TabController(
      length: pages.length,
      vsync: this,
    );
    appdata.settings.addListener(onSettingsChanged);
    NaviPane.of(context).addNaviItemTapListener(onNaviItemTapped);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    naviPane = NaviPane.of(context);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    controller.dispose();
    appdata.settings.removeListener(onSettingsChanged);
    naviPane?.removeNaviItemTapListener(onNaviItemTapped);
    super.dispose();
  }

  void refresh() {
    int page = controller.index;
    String currentPageId = pages[page];
    GlobalState.find<_SingleExplorePageState>(currentPageId).refresh();
  }

  Widget buildFAB() => Material(
        color: Colors.transparent,
        child: FloatingActionButton(
          key: const Key("FAB"),
          onPressed: refresh,
          child: const Icon(Icons.refresh),
        ),
      );

  Tab buildTab(String i) {
    var comicSource = ComicSource.all()
        .firstWhere((e) => e.explorePages.any((e) => e.title == i));
    return Tab(text: i.ts(comicSource.key), key: Key(i));
  }

  Widget buildBody(String i) => Material(
        child: _SingleExplorePage(i, key: PageStorageKey(i)),
      );

  Widget buildEmpty() {
    var msg = "No Explore Pages".tl;
    msg += '\n';
    VoidCallback onTap;
    if (ComicSource.isEmpty) {
      msg += "Please add some sources".tl;
      onTap = () {
        context.to(() => ComicSourcePage());
      };
    } else {
      msg += "Please check your settings".tl;
      onTap = addPage;
    }
    return NetworkError(
      message: msg,
      retry: onTap,
      withAppbar: false,
      buttonText: "Manage".tl,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (pages.isEmpty) {
      return buildEmpty();
    }

    Widget tabBar = Material(
      child: AppTabBar(
        key: PageStorageKey(pages.toString()),
        tabs: pages.map((e) => buildTab(e)).toList(),
        controller: controller,
        actionButton: TabActionButton(
          icon: const Icon(Icons.add),
          text: "Add".tl,
          onPressed: addPage,
        ),
      ),
    ).paddingTop(context.padding.top);

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              tabBar,
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notifications) {
                    if (notifications.metrics.axis == Axis.horizontal) {
                      if (!showFB) {
                        setState(() {
                          showFB = true;
                        });
                      }
                      return true;
                    }

                    var current = notifications.metrics.pixels;
                    var overflow = notifications.metrics.outOfRange;
                    if (current > location && current != 0 && showFB) {
                      setState(() {
                        showFB = false;
                      });
                    } else if ((current < location - 50 || current == 0) &&
                        !showFB) {
                      setState(() {
                        showFB = true;
                      });
                    }
                    if ((current > location || current < location - 50) &&
                        !overflow) {
                      location = current;
                    }
                    return false;
                  },
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: TabBarView(
                      controller: controller,
                      children: pages.map((e) => buildBody(e)).toList(),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            reverseDuration: const Duration(milliseconds: 150),
            child: showFB ? buildFAB() : const SizedBox(),
            transitionBuilder: (widget, animation) {
              var tween = Tween<Offset>(
                  begin: const Offset(0, 1), end: const Offset(0, 0));
              return SlideTransition(
                position: tween.animate(animation),
                child: widget,
              );
            },
          ),
        )
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _SingleExplorePage extends StatefulWidget {
  const _SingleExplorePage(this.title, {super.key});

  final String title;

  @override
  State<_SingleExplorePage> createState() => _SingleExplorePageState();
}

class _SingleExplorePageState extends AutomaticGlobalState<_SingleExplorePage>
    with AutomaticKeepAliveClientMixin<_SingleExplorePage> {
  late final ExplorePageData data;

  late final String comicSourceKey;

  bool _wantKeepAlive = true;

  var scrollController = ScrollController();

  VoidCallback? refreshHandler;

  void onSettingsChanged() {
    var explorePages = appdata.settings["explore_pages"];
    if (!explorePages.contains(widget.title)) {
      _wantKeepAlive = false;
      updateKeepAlive();
    }
  }

  @override
  void initState() {
    super.initState();
    for (var source in ComicSource.all()) {
      for (var d in source.explorePages) {
        if (d.title == widget.title) {
          data = d;
          comicSourceKey = source.key;
          return;
        }
      }
    }
    appdata.settings.addListener(onSettingsChanged);
    throw "Explore Page ${widget.title} Not Found!";
  }

  @override
  void dispose() {
    appdata.settings.removeListener(onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (data.loadMultiPart != null) {
      return _MultiPartExplorePage(
        key: const PageStorageKey("comic_list"),
        data: data,
        controller: scrollController,
        comicSourceKey: comicSourceKey,
        refreshHandlerCallback: (c) {
          refreshHandler = c;
        },
      );
    } else if (data.loadPage != null || data.loadNext != null) {
      return ComicList(
        enablePageStorage: true,
        loadPage: data.loadPage,
        loadNext: data.loadNext,
        key: const PageStorageKey("comic_list"),
        controller: scrollController,
        refreshHandlerCallback: (c) {
          refreshHandler = c;
        },
      );
    } else if (data.loadMixed != null) {
      return _MixedExplorePage(
        data,
        comicSourceKey,
        key: const PageStorageKey("comic_list"),
        controller: scrollController,
        refreshHandlerCallback: (c) {
          refreshHandler = c;
        },
      );
    } else {
      return const Center(
        child: Text("Empty Page"),
      );
    }
  }

  @override
  Object? get key => widget.title;

  @override
  void refresh() {
    refreshHandler?.call();
  }

  @override
  bool get wantKeepAlive => _wantKeepAlive;

  void toTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }
}

class _MixedExplorePage extends StatefulWidget {
  const _MixedExplorePage(this.data, this.sourceKey,
      {super.key, this.controller, required this.refreshHandlerCallback});

  final ExplorePageData data;

  final String sourceKey;

  final ScrollController? controller;

  final void Function(VoidCallback c) refreshHandlerCallback;

  @override
  State<_MixedExplorePage> createState() => _MixedExplorePageState();
}

class _MixedExplorePageState
    extends MultiPageLoadingState<_MixedExplorePage, Object> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshHandlerCallback(refresh);
  }

  void refresh() {
    reset();
  }

  Iterable<Widget> buildSlivers(BuildContext context, List<Object> data) sync* {
    List<Comic> cache = [];
    for (var part in data) {
      if (part is ExplorePagePart) {
        if (cache.isNotEmpty) {
          yield SliverGridComics(
            comics: (cache),
          );
          yield const SliverToBoxAdapter(child: Divider());
          cache.clear();
        }
        yield* _buildExplorePagePart(part, widget.sourceKey);
        yield const SliverToBoxAdapter(child: Divider());
      } else {
        cache.addAll(part as List<Comic>);
      }
    }
    if (cache.isNotEmpty) {
      yield SliverGridComics(
        comics: (cache),
      );
    }
  }

  @override
  Widget buildContent(BuildContext context, List<Object> data) {
    if (appdata.settings['eInkMode'] == true) {
      return _EInkExplorePartsPager(
        parts: _objectsToParts(data),
        sourceKey: widget.sourceKey,
        onLastPage: haveNextPage ? nextPage : null,
      );
    }
    return SmoothCustomScrollView(
      controller: widget.controller,
      slivers: [
        ...buildSlivers(context, data),
        const SliverListLoadingIndicator(),
      ],
    );
  }

  List<ExplorePagePart> _objectsToParts(List<Object> data) {
    final parts = <ExplorePagePart>[];
    final cache = <Comic>[];
    void flushCache() {
      if (cache.isEmpty) {
        return;
      }
      parts.add(ExplorePagePart("", List<Comic>.from(cache), null));
      cache.clear();
    }

    for (final part in data) {
      if (part is ExplorePagePart) {
        flushCache();
        parts.add(part);
      } else {
        cache.addAll(part as List<Comic>);
      }
    }
    flushCache();
    return parts;
  }

  @override
  Future<Res<List<Object>>> loadData(int page) async {
    var res = await widget.data.loadMixed!(page);
    if (res.error) {
      return res;
    }
    for (var element in res.data) {
      if (element is! ExplorePagePart && element is! List<Comic>) {
        return const Res.error("function loadMixed return invalid data");
      }
    }
    return res;
  }
}

Iterable<Widget> _buildExplorePagePart(
    ExplorePagePart part, String sourceKey) sync* {
  Widget buildTitle(ExplorePagePart part) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 5, 10),
          child: Row(
            children: [
              Text(
                part.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (part.viewMore != null)
                TextButton(
                  onPressed: () {
                    var context = App.mainNavigatorKey!.currentContext!;
                    part.viewMore!.jump(context);
                  },
                  child: Text("View more".tl),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget buildComics(ExplorePagePart part) {
    return SliverGridComics(comics: part.comics);
  }

  yield buildTitle(part);
  yield buildComics(part);
}

class _MultiPartExplorePage extends StatefulWidget {
  const _MultiPartExplorePage({
    super.key,
    required this.data,
    required this.controller,
    required this.comicSourceKey,
    required this.refreshHandlerCallback,
  });

  final ExplorePageData data;

  final ScrollController controller;

  final String comicSourceKey;

  final void Function(VoidCallback c) refreshHandlerCallback;

  @override
  State<_MultiPartExplorePage> createState() => _MultiPartExplorePageState();
}

class _MultiPartExplorePageState extends State<_MultiPartExplorePage> {
  late final ExplorePageData data;

  List<ExplorePagePart>? parts;

  bool loading = true;

  String? message;

  Map<String, dynamic> get state => {
        "loading": loading,
        "message": message,
        "parts": parts,
      };

  void restoreState(dynamic state) {
    if (state is! Map) return;
    try {
      loading = state["loading"] is bool ? state["loading"] as bool : true;
      final restoredMessage = state["message"];
      message = restoredMessage is String ? restoredMessage : null;
      final restoredParts = state["parts"];
      if (restoredParts is List<ExplorePagePart>) {
        parts = restoredParts;
      } else if (restoredParts is List) {
        parts = restoredParts.cast<ExplorePagePart>();
      }
    } catch (_) {
      loading = true;
      message = null;
      parts = null;
    }
  }

  Object get _storageIdentifier =>
      "multi-part-explore-state-${widget.key ?? hashCode}";

  void storeState() {
    PageStorage.of(context)
        .writeState(context, state, identifier: _storageIdentifier);
  }

  void refresh() {
    setState(() {
      loading = true;
      message = null;
      parts = null;
    });
    storeState();
  }

  @override
  void initState() {
    super.initState();
    data = widget.data;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    restoreState(
      PageStorage.of(context).readState(
        context,
        identifier: _storageIdentifier,
      ),
    );
    widget.refreshHandlerCallback(refresh);
  }

  void load() async {
    var res = await data.loadMultiPart!();
    loading = false;
    if (mounted) {
      setState(() {
        if (res.error) {
          message = res.errorMessage;
        } else {
          parts = res.data;
        }
      });
      storeState();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      load();
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else if (message != null) {
      return NetworkError(
        message: message!,
        retry: () {
          setState(() {
            loading = true;
            message = null;
          });
        },
        withAppbar: false,
      );
    } else {
      return buildPage();
    }
  }

  Widget buildPage() {
    if (appdata.settings['eInkMode'] == true) {
      return _EInkExplorePartsPager(
        parts: parts!,
        sourceKey: widget.comicSourceKey,
      );
    }
    return SmoothCustomScrollView(
      key: const PageStorageKey('scroll'),
      controller: widget.controller,
      slivers: _buildPage().toList(),
    );
  }

  Iterable<Widget> _buildPage() sync* {
    for (var part in parts!) {
      yield* _buildExplorePagePart(part, widget.comicSourceKey);
    }
  }
}

class _EInkExplorePartsPager extends StatefulWidget {
  const _EInkExplorePartsPager({
    required this.parts,
    required this.sourceKey,
    this.onLastPage,
  });

  final List<ExplorePagePart> parts;

  final String sourceKey;

  final VoidCallback? onLastPage;

  @override
  State<_EInkExplorePartsPager> createState() => _EInkExplorePartsPagerState();
}

class _EInkExplorePartsPagerState extends State<_EInkExplorePartsPager> {
  int _page = 0;

  int _lastPageCount = 1;

  bool _lastPageNotified = false;

  bool get _canHandleVolumeKey {
    if (appdata.settings['eInkMode'] != true || !App.isAndroid) {
      return false;
    }
    if (appdata.settings['enableTurnPageByVolumeKey'] != true) {
      return false;
    }
    if (!TickerMode.of(context)) {
      return false;
    }
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  @override
  void initState() {
    super.initState();
    appdata.settings.addListener(_onSettingsChanged);
    _configureVolumeListener();
  }

  @override
  void didUpdateWidget(covariant _EInkExplorePartsPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.parts.isEqualTo(widget.parts)) {
      _lastPageNotified = false;
      if (_page >= _lastPageCount) {
        _page = math.max(0, _lastPageCount - 1);
      }
    }
  }

  @override
  void dispose() {
    VolumePageTurnRegistry.unregister(this);
    appdata.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    _configureVolumeListener();
    if (mounted) {
      setState(() {});
    }
  }

  void _configureVolumeListener() {
    final shouldListen = appdata.settings['eInkMode'] == true &&
        App.isAndroid &&
        appdata.settings['enableTurnPageByVolumeKey'] == true;
    if (!shouldListen) {
      VolumePageTurnRegistry.unregister(this);
      return;
    }
    VolumePageTurnRegistry.register(
      this,
      canHandle: () => _canHandleVolumeKey,
      onDown: _toNextPage,
      onUp: _toPreviousPage,
    );
  }

  void _toNextPage() {
    if (_page >= _lastPageCount - 1) {
      widget.onLastPage?.call();
      return;
    }
    setState(() {
      _page++;
      _lastPageNotified = false;
    });
  }

  void _toPreviousPage() {
    if (_page <= 0) {
      return;
    }
    setState(() {
      _page--;
      _lastPageNotified = false;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -80) {
      _toNextPage();
    } else if (velocity > 80) {
      _toPreviousPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.parts.isEmpty) {
      return Center(
        child: Text("Empty Page".tl),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const selectorHeight = 52.0;
        const titleHeight = 60.0;
        final gridHeight =
            math.max(1.0, constraints.maxHeight - selectorHeight - titleHeight);
        final metrics = _EInkExploreGridMetrics.fromSize(
          context,
          Size(constraints.maxWidth, gridHeight),
        );
        final slices = _buildSlices(metrics.pageSize);
        _lastPageCount = math.max(1, slices.length);
        if (_page >= _lastPageCount) {
          _page = _lastPageCount - 1;
        }
        if (_page == _lastPageCount - 1 &&
            widget.onLastPage != null &&
            !_lastPageNotified) {
          _lastPageNotified = true;
          Future.microtask(widget.onLastPage!);
        }
        final slice = slices[_page];
        final part = widget.parts[slice.partIndex];
        final comics = part.comics.sublist(slice.start, slice.end);

        return Column(
          children: [
            _buildPageSelector(),
            _buildTitle(part),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: _handleDragEnd,
                child: _EInkExploreComicGrid(
                  comics: comics,
                  metrics: metrics,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPageSelector() {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          FilledButton(
            onPressed: _page > 0 ? _toPreviousPage : null,
            child: Text("Back".tl),
          ).fixWidth(84),
          Expanded(
            child: Center(
              child: Text(
                "${"Page".tl} ${_page + 1} / $_lastPageCount",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          FilledButton(
            onPressed: _page < _lastPageCount - 1 || widget.onLastPage != null
                ? _toNextPage
                : null,
            child: Text("Next".tl),
          ).fixWidth(84),
        ],
      ).paddingHorizontal(16),
    );
  }

  Widget _buildTitle(ExplorePagePart part) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 5, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                part.title.isEmpty ? widget.sourceKey : part.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (part.viewMore != null)
              TextButton(
                onPressed: () {
                  var context = App.mainNavigatorKey!.currentContext!;
                  part.viewMore!.jump(context);
                },
                child: Text("View more".tl),
              )
          ],
        ),
      ),
    );
  }

  List<_EInkExplorePageSlice> _buildSlices(int pageSize) {
    final slices = <_EInkExplorePageSlice>[];
    for (var partIndex = 0; partIndex < widget.parts.length; partIndex++) {
      final comics = widget.parts[partIndex].comics;
      if (comics.isEmpty) {
        slices.add(_EInkExplorePageSlice(partIndex, 0, 0));
        continue;
      }
      for (var start = 0; start < comics.length; start += pageSize) {
        slices.add(
          _EInkExplorePageSlice(
            partIndex,
            start,
            math.min(start + pageSize, comics.length),
          ),
        );
      }
    }
    return slices.isEmpty ? [_EInkExplorePageSlice(0, 0, 0)] : slices;
  }
}

class _EInkExplorePageSlice {
  const _EInkExplorePageSlice(this.partIndex, this.start, this.end);

  final int partIndex;
  final int start;
  final int end;
}

class _EInkExploreGridMetrics {
  const _EInkExploreGridMetrics({
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.pageSize,
  });

  final int crossAxisCount;
  final double childAspectRatio;
  final int pageSize;

  factory _EInkExploreGridMetrics.fromSize(BuildContext context, Size size) {
    final scale = (appdata.settings['comicTileScale'] as num).toDouble();
    final width = math.max(1.0, size.width);
    final height = math.max(1.0, size.height - context.padding.bottom);
    if (appdata.settings['comicDisplayMode'] == 'brief') {
      final maxCrossAxisExtent = math.max(80.0, 192.0 * scale);
      final crossAxisCount =
          math.max(1, (width / maxCrossAxisExtent).ceil());
      final itemWidth = width / crossAxisCount;
      final itemHeight = itemWidth / 0.64;
      final rows = math.max(1, height ~/ itemHeight);
      return _EInkExploreGridMetrics(
        crossAxisCount: crossAxisCount,
        childAspectRatio: itemWidth / itemHeight,
        pageSize: math.max(1, crossAxisCount * rows),
      );
    }
    final itemHeight = math.max(96.0, 152.0 * scale);
    final crossAxisCount = math.max(1, width ~/ 360.0);
    final itemWidth = width / crossAxisCount;
    final rows = math.max(1, height ~/ itemHeight);
    return _EInkExploreGridMetrics(
      crossAxisCount: crossAxisCount,
      childAspectRatio: itemWidth / itemHeight,
      pageSize: math.max(1, crossAxisCount * rows),
    );
  }
}

class _EInkExploreComicGrid extends StatelessWidget {
  const _EInkExploreComicGrid({
    required this.comics,
    required this.metrics,
  });

  final List<Comic> comics;

  final _EInkExploreGridMetrics metrics;

  @override
  Widget build(BuildContext context) {
    if (comics.isEmpty) {
      return Center(
        child: Text("No search results found".tl),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.only(bottom: context.padding.bottom),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: metrics.crossAxisCount,
        childAspectRatio: metrics.childAspectRatio,
      ),
      itemBuilder: (context, index) {
        return ComicTile(comic: comics[index]);
      },
    );
  }
}
