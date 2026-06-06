import "dart:math" as math;

import "package:flutter/material.dart";
import 'package:shimmer_animation/shimmer_animation.dart';
import "package:venera/components/components.dart";
import "package:venera/foundation/app.dart";
import "package:venera/foundation/appdata.dart";
import "package:venera/foundation/comic_source/comic_source.dart";
import "package:venera/foundation/res.dart";
import "package:venera/pages/search_result_page.dart";
import "package:venera/utils/translations.dart";
import "package:venera/utils/volume.dart";

class AggregatedSearchPage extends StatefulWidget {
  const AggregatedSearchPage({super.key, required this.keyword});

  final String keyword;

  @override
  State<AggregatedSearchPage> createState() => _AggregatedSearchPageState();
}

class _AggregatedSearchPageState extends State<AggregatedSearchPage> {
  late final List<ComicSource> sources;

  late final SearchBarController controller;

  var _keyword = "";

  int _sourcePage = 0;

  int _lastSourcePageCount = 1;

  final _resultCache = <String, _AggregatedSearchResultCache>{};

  final _preloadingKeys = <String>{};

  static const _kSourceRowHeight = 236.0;

  bool get _eInkMode => appdata.settings['eInkMode'] == true;

  @override
  void initState() {
    super.initState();
    var all = ComicSource.all()
        .where((e) => e.searchPageData != null)
        .map((e) => e.key)
        .toList();
    var settings = appdata.settings['searchSources'] as List;
    var sources = <String>[];
    for (var source in settings) {
      if (all.contains(source)) {
        sources.add(source);
      }
    }
    this.sources = sources.map((e) => ComicSource.find(e)!).toList();
    _keyword = widget.keyword;
    controller = SearchBarController(
      currentText: widget.keyword,
      onSearch: (text) {
        setState(() {
          _keyword = text;
          _sourcePage = 0;
          _resultCache.clear();
          _preloadingKeys.clear();
        });
      },
    );
    appdata.settings.addListener(_onSettingsChanged);
    _configureVolumeListener();
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

  bool get _canHandleVolumeKey {
    if (!_eInkMode || !App.isAndroid) {
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

  void _configureVolumeListener() {
    final shouldListen = _eInkMode &&
        App.isAndroid &&
        appdata.settings['enableTurnPageByVolumeKey'] == true;
    if (!shouldListen) {
      VolumePageTurnRegistry.unregister(this);
      return;
    }
    VolumePageTurnRegistry.register(
      this,
      canHandle: () => _canHandleVolumeKey,
      onDown: () {
        _toNextSourcePage();
      },
      onUp: () {
        _toPreviousSourcePage();
      },
    );
  }

  void _toNextSourcePage() {
    if (_sourcePage >= _lastSourcePageCount - 1) {
      return;
    }
    setState(() {
      _sourcePage++;
    });
  }

  void _toPreviousSourcePage() {
    if (_sourcePage <= 0) {
      return;
    }
    setState(() {
      _sourcePage--;
    });
  }

  String _cacheKeyFor(ComicSource source) => "${source.key}\n$_keyword";

  void _preloadSourceResults(Iterable<ComicSource> sources) {
    if (!_eInkMode) {
      return;
    }
    for (final source in sources) {
      final cacheKey = _cacheKeyFor(source);
      if (_resultCache.containsKey(cacheKey) ||
          _preloadingKeys.contains(cacheKey)) {
        continue;
      }
      _preloadingKeys.add(cacheKey);
      _preloadSourceResult(source, cacheKey);
    }
  }

  void _preloadSourceResult(ComicSource source, String cacheKey) async {
    try {
      final data = source.searchPageData!;
      var options =
          (data.searchOptions ?? []).map((e) => e.defaultValue).toList();
      Res<List<Comic>> res;
      if (data.loadPage != null) {
        res = await data.loadPage!(_keyword, 1, options);
      } else {
        res = await data.loadNext!(_keyword, null, options);
      }
      if (res.success) {
        _resultCache[cacheKey] = _AggregatedSearchResultCache(
          comics: res.data,
          error: null,
        );
      } else {
        _resultCache[cacheKey] = _AggregatedSearchResultCache(
          comics: null,
          error: res.errorMessage ?? "Unknown error".tl,
        );
      }
    } finally {
      _preloadingKeys.remove(cacheKey);
    }
  }

  void _handleEInkDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -80) {
      _toNextSourcePage();
    } else if (velocity > 80) {
      _toPreviousSourcePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_eInkMode) {
      return buildEInkPage();
    }
    return SmoothCustomScrollView(slivers: [
      SliverSearchBar(controller: controller),
      SliverList(
        key: ValueKey(_keyword),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final source = sources[index];
            return _SliverSearchResult(
              key: ValueKey(source.key),
              source: source,
              keyword: _keyword,
              cache: _resultCache,
            );
          },
          childCount: sources.length,
        ),
      ),
    ]);
  }

  Widget buildEInkPage() {
    return Column(
      children: [
        AppSearchBar(controller: controller),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const selectorHeight = 52.0;
              final sourceAreaHeight =
                  math.max(1.0, constraints.maxHeight - selectorHeight);
              final rowsPerPage = math.max(
                1,
                (sourceAreaHeight / _kSourceRowHeight).floor(),
              );
              final sourcePageCount =
                  math.max(1, (sources.length / rowsPerPage).ceil());
              _lastSourcePageCount = sourcePageCount;
              if (_sourcePage >= sourcePageCount) {
                _sourcePage = sourcePageCount - 1;
              }
              final start = _sourcePage * rowsPerPage;
              final end = math.min(start + rowsPerPage, sources.length);
              final pageSources = start >= sources.length
                  ? const <ComicSource>[]
                  : sources.sublist(start, end);
              final preloadEnd = math.min(end + rowsPerPage, sources.length);
              if (end < preloadEnd) {
                _preloadSourceResults(sources.sublist(end, preloadEnd));
              }

              return Column(
                children: [
                  _buildEInkPageSelector(sourcePageCount),
                  Expanded(
                    child: pageSources.isEmpty
                        ? Center(
                            child: Text("Empty Page".tl),
                          )
                        : GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragEnd: _handleEInkDragEnd,
                            child: Column(
                              children: [
                                for (final source in pageSources)
                                  SizedBox(
                                    height: _kSourceRowHeight,
                                    child: _SliverSearchResult(
                                      key: ValueKey(
                                          "${_keyword}_${source.key}"),
                                      source: source,
                                      keyword: _keyword,
                                      cache: _resultCache,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEInkPageSelector([int? sourcePageCount]) {
    final pageCount = sourcePageCount ?? _lastSourcePageCount;
    final canGoBack = _sourcePage > 0;
    final canGoNext = _sourcePage < pageCount - 1;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          FilledButton(
            onPressed: canGoBack ? _toPreviousSourcePage : null,
            child: Text("Back".tl),
          ).fixWidth(84),
          Expanded(
            child: Center(
              child: Text(
                "${"Page".tl} ${_sourcePage + 1} / $pageCount",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          FilledButton(
            onPressed: canGoNext ? _toNextSourcePage : null,
            child: Text("Next".tl),
          ).fixWidth(84),
        ],
      ).paddingHorizontal(16),
    );
  }
}

class _SliverSearchResult extends StatefulWidget {
  const _SliverSearchResult({
    required this.source,
    required this.keyword,
    required this.cache,
    super.key,
  });

  final ComicSource source;

  final String keyword;

  final Map<String, _AggregatedSearchResultCache> cache;

  @override
  State<_SliverSearchResult> createState() => _SliverSearchResultState();
}

class _AggregatedSearchResultCache {
  _AggregatedSearchResultCache({
    this.comics,
    this.error,
    this.comicPage = 0,
  });

  List<Comic>? comics;

  String? error;

  int comicPage;
}

class _SliverSearchResultState extends State<_SliverSearchResult>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;

  static const _kComicHeight = 176.0;

  double get _comicHeight =>
      appdata.settings['eInkMode'] == true ? 162.0 : _kComicHeight;

  static const _kComicWidth = 98.0;

  static const _kLeftPadding = 16.0;

  static const _kComicSlotWidth = _kComicWidth + _kLeftPadding;

  List<Comic>? comics;

  String? error;

  int _comicPage = 0;

  String get _cacheKey => "${widget.source.key}\n${widget.keyword}";

  void _restoreFromCache() {
    final cache = widget.cache[_cacheKey];
    if (cache == null) {
      return;
    }
    comics = cache.comics;
    error = cache.error;
    _comicPage = cache.comicPage;
    isLoading = false;
  }

  void _storeInCache() {
    widget.cache[_cacheKey] = _AggregatedSearchResultCache(
      comics: comics,
      error: error,
      comicPage: _comicPage,
    );
  }

  void load() async {
    if (widget.cache.containsKey(_cacheKey)) {
      return;
    }
    final data = widget.source.searchPageData!;
    var options =
        (data.searchOptions ?? []).map((e) => e.defaultValue).toList();
    if (data.loadPage != null) {
      var res = await data.loadPage!(widget.keyword, 1, options);
      if (!res.error) {
        comics = res.data;
        error = null;
        isLoading = false;
        _storeInCache();
        if (!mounted) {
          return;
        }
        setState(() {
          comics = res.data;
          error = null;
          isLoading = false;
        });
      } else {
        comics = null;
        error = res.errorMessage ?? "Unknown error".tl;
        isLoading = false;
        _storeInCache();
        if (!mounted) {
          return;
        }
        setState(() {
          comics = null;
          error = res.errorMessage ?? "Unknown error".tl;
          isLoading = false;
        });
      }
    } else if (data.loadNext != null) {
      var res = await data.loadNext!(widget.keyword, null, options);
      if (!res.error) {
        comics = res.data;
        error = null;
        isLoading = false;
        _storeInCache();
        if (!mounted) {
          return;
        }
        setState(() {
          comics = res.data;
          error = null;
          isLoading = false;
        });
      } else {
        comics = null;
        error = res.errorMessage ?? "Unknown error".tl;
        isLoading = false;
        _storeInCache();
        if (!mounted) {
          return;
        }
        setState(() {
          comics = null;
          error = res.errorMessage ?? "Unknown error".tl;
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _restoreFromCache();
    if (isLoading) {
      load();
    }
  }

  Widget buildPlaceHolder() {
    return Container(
      height: _comicHeight,
      width: _kComicWidth,
      margin: const EdgeInsets.only(left: _kLeftPadding),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget buildComic(Comic c) {
    return SimpleComicTile(comic: c, withTitle: true)
        .paddingLeft(_kLeftPadding)
        .paddingBottom(2);
  }

  Widget buildPlaceholders({required bool shimmer}) {
    final content = LayoutBuilder(builder: (context, constrains) {
      var items = (constrains.maxWidth / _kComicSlotWidth).ceil();
      return Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Row(
              children: List.generate(
                items,
                (index) => buildPlaceHolder(),
              ),
            ),
          )
        ],
      );
    });
    return shimmer ? Shimmer(child: content) : content;
  }

  Widget buildComicsStrip() {
    if (appdata.settings['eInkMode'] == true) {
      return LayoutBuilder(builder: (context, constrains) {
        const controlWidth = 40.0;
        const labelWidth = 48.0;
        final availableWidth =
            math.max(1.0, constrains.maxWidth - controlWidth * 2 - labelWidth);
        var items = math.max(
          1,
          (availableWidth / _kComicSlotWidth).floor(),
        );
        final pageCount = math.max(1, (comics!.length / items).ceil());
        if (_comicPage >= pageCount) {
          _comicPage = pageCount - 1;
          widget.cache[_cacheKey]?.comicPage = _comicPage;
        }
        final start = _comicPage * items;
        final end = math.min(start + items, comics!.length);
        final pageComics = start >= comics!.length
            ? const <Comic>[]
            : comics!.sublist(start, end);
        return Row(
          children: [
            IconButton(
              onPressed: _comicPage > 0
                  ? () {
                      setState(() {
                        _comicPage--;
                      });
                      widget.cache[_cacheKey]?.comicPage = _comicPage;
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: "Back".tl,
            ).fixWidth(controlWidth),
            Expanded(
              child: Row(
                children: [
                  for (var c in pageComics) buildComic(c),
                ],
              ),
            ),
            SizedBox(
              width: labelWidth,
              child: Center(
                child: Text(
                  "${_comicPage + 1}/$pageCount",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              onPressed: _comicPage < pageCount - 1
                  ? () {
                      setState(() {
                        _comicPage++;
                      });
                      widget.cache[_cacheKey]?.comicPage = _comicPage;
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: "Next".tl,
            ).fixWidth(controlWidth),
          ],
        );
      });
    }
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (var c in comics!) buildComic(c),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (error != null && error!.startsWith("CloudflareException")) {
      error = "Cloudflare verification required".tl;
    }
    super.build(context);
    return InkWell(
      onTap: () {
        context.to(
          () => SearchResultPage(
            text: widget.keyword,
            sourceKey: widget.source.key,
          ),
        );
      },
      child: Column(
        children: [
          ListTile(
            mouseCursor: SystemMouseCursors.click,
            title: Text(widget.source.name),
          ),
          if (isLoading)
            SizedBox(
              height: _comicHeight,
              width: double.infinity,
              child: buildPlaceholders(
                shimmer: appdata.settings['eInkMode'] != true,
              ),
            )
          else if (error != null || comics == null || comics!.isEmpty)
            SizedBox(
              height: _comicHeight,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error ?? "No search results found".tl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    ],
                  ),
                  const Spacer(),
                ],
              ).paddingHorizontal(16),
            )
          else
            SizedBox(
              height: _comicHeight,
              child: buildComicsStrip(),
            ),
        ],
      ).paddingBottom(appdata.settings['eInkMode'] == true ? 4 : 16),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
