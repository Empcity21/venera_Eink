part of 'components.dart';

ImageProvider? _findImageProvider(Comic comic) {
  ImageProvider image;
  if (comic is LocalComic) {
    image = LocalComicImageProvider(comic);
  } else if (comic is History) {
    image = HistoryImageProvider(comic);
  } else if (comic.sourceKey == 'local') {
    var localComic = LocalManager().find(comic.id, ComicType.local);
    if (localComic == null) {
      return null;
    }
    image = FileImage(localComic.coverFile);
  } else {
    image = CachedImageProvider(
      comic.cover,
      sourceKey: comic.sourceKey,
      cid: comic.id,
      fallbackToLocalCover: comic is FavoriteItem,
    );
  }
  return image;
}

class ComicTile extends StatelessWidget {
  const ComicTile({
    super.key,
    required this.comic,
    this.enableLongPressed = true,
    this.badge,
    this.menuOptions,
    this.onTap,
    this.onLongPressed,
    this.heroID,
  });

  final Comic comic;

  final bool enableLongPressed;

  final String? badge;

  final List<MenuEntry>? menuOptions;

  final VoidCallback? onTap;

  final VoidCallback? onLongPressed;

  final int? heroID;

  void _onTap() {
    if (onTap != null) {
      onTap!();
      return;
    }
    App.mainNavigatorKey?.currentContext?.to(
      () => ComicPage(
        id: comic.id,
        sourceKey: comic.sourceKey,
        cover: comic.cover,
        title: comic.title,
        heroID: heroID,
      ),
    );
  }

  void _onLongPressed(context) {
    if (onLongPressed != null) {
      onLongPressed!();
      return;
    }
    onLongPress(context);
  }

  void onLongPress(BuildContext context) {
    var renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var location = renderBox.localToGlobal(
      Offset((size.width - 242) / 2, size.height / 2),
    );
    showMenu(location, context);
  }

  void onSecondaryTap(TapDownDetails details, BuildContext context) {
    showMenu(details.globalPosition, context);
  }

  void showMenu(Offset location, BuildContext context) {
    showMenuX(
      App.rootContext,
      location,
      [
        MenuEntry(
          icon: Icons.chrome_reader_mode_outlined,
          text: 'Details'.tl,
          onClick: () {
            App.mainNavigatorKey?.currentContext?.to(
              () => ComicPage(
                id: comic.id,
                sourceKey: comic.sourceKey,
                cover: comic.cover,
                title: comic.title,
              ),
            );
          },
        ),
        MenuEntry(
          icon: Icons.copy,
          text: 'Copy Title'.tl,
          onClick: () {
            Clipboard.setData(ClipboardData(text: comic.title));
            App.rootContext.showMessage(message: 'Title copied'.tl);
          },
        ),
        MenuEntry(
          icon: Icons.stars_outlined,
          text: 'Add to favorites'.tl,
          onClick: () {
            addFavorite([comic]);
          },
        ),
        MenuEntry(
          icon: Icons.block,
          text: 'Block'.tl,
          onClick: () => block(context),
        ),
        ...?menuOptions,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var type = appdata.settings['comicDisplayMode'];

    Widget child = type == 'detailed'
        ? _buildDetailedMode(context)
        : _buildBriefMode(context);

    var isFavorite = appdata.settings['showFavoriteStatusOnTile']
        ? LocalFavoritesManager()
            .isExist(comic.id, ComicType(comic.sourceKey.hashCode))
        : false;
    var history = appdata.settings['showHistoryStatusOnTile']
        ? HistoryManager().find(comic.id, ComicType(comic.sourceKey.hashCode))
        : null;
    if (history?.page == 0) {
      history!.page = 1;
    }

    if (!isFavorite && history == null) {
      return child;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: child,
        ),
        Positioned(
          left: type == 'detailed' ? 16 : 6,
          top: 8,
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                if (isFavorite)
                  Container(
                    height: 24,
                    width: 24,
                    color: Colors.green,
                    child: const Icon(
                      Icons.bookmark_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                if (history != null)
                  Container(
                    height: 24,
                    color: Colors.blue.toOpacity(0.9),
                    constraints: const BoxConstraints(minWidth: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: CustomPaint(
                      painter:
                          _ReadingHistoryPainter(history.page, history.maxPage),
                    ),
                  )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget buildImage(BuildContext context) {
    var image = _findImageProvider(comic);
    if (image == null) {
      return const SizedBox();
    }
    return AnimatedImage(
      image: image,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _buildDetailedMode(BuildContext context) {
    return LayoutBuilder(builder: (context, constrains) {
      final height = constrains.maxHeight - 16;

      Widget image = Container(
        width: height * 0.68,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.outlineVariant,
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: buildImage(context),
      );

      if (heroID != null) {
        image = Hero(
          tag: "cover$heroID",
          child: image,
        );
      }

      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _onTap,
        onLongPress: enableLongPressed ? () => _onLongPressed(context) : null,
        onSecondaryTapDown: (detail) => onSecondaryTap(detail, context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
          child: Row(
            children: [
              image,
              SizedBox.fromSize(
                size: const Size(16, 5),
              ),
              Expanded(
                child: _ComicDescription(
                  title: comic.maxPage == null
                      ? comic.title.replaceAll("\n", "")
                      : "[${comic.maxPage}P]${comic.title.replaceAll("\n", "")}",
                  subtitle: comic.subtitle ?? '',
                  description: comic.description,
                  badge: badge ?? comic.language,
                  tags: comic.tags,
                  maxLines: 2,
                  enableTranslate:
                      ComicSource.find(comic.sourceKey)?.enableTagsTranslate ??
                          false,
                  rating: comic.stars,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBriefMode(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget image = Container(
          decoration: BoxDecoration(
            color: context.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.toOpacity(0.2),
                blurRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: buildImage(context),
        );

        if (heroID != null) {
          image = Hero(
            tag: "cover$heroID",
            child: image,
          );
        }

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _onTap,
          onLongPress: enableLongPressed ? () => _onLongPressed(context) : null,
          onSecondaryTapDown: (detail) => onSecondaryTap(detail, context),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: image,
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: (() {
                        final subtitle =
                            comic.subtitle?.replaceAll('\n', '').trim();
                        final text = comic.description.isNotEmpty
                            ? comic.description.split('|').join('\n')
                            : (subtitle?.isNotEmpty == true ? subtitle : null);
                        final fortSize = constraints.maxWidth < 80
                            ? 8.0
                            : constraints.maxWidth < 150
                                ? 10.0
                                : 12.0;

                        if (text == null) {
                          return const SizedBox();
                        }

                        var children = <Widget>[];
                        var lines = text.split('\n');
                        lines.removeWhere((e) => e.trim().isEmpty);
                        if (lines.length > 3) {
                          lines = lines.sublist(0, 3);
                        }
                        for (var line in lines) {
                          children.add(Container(
                            margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
                            padding: constraints.maxWidth < 80
                                ? const EdgeInsets.fromLTRB(3, 1, 3, 1)
                                : constraints.maxWidth < 150
                                    ? const EdgeInsets.fromLTRB(4, 2, 4, 2)
                                    : const EdgeInsets.fromLTRB(5, 2, 5, 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.black.toOpacity(0.5),
                            ),
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                            ),
                            child: Text(
                              line,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: fortSize,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ));
                        }
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: children,
                        );
                      })(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(
                  comic.title.replaceAll('\n', ''),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ).paddingHorizontal(6).paddingVertical(8),
        );
      },
    );
  }

  List<String> _splitText(String text) {
    // split text by comma, brackets
    var words = <String>[];
    var buffer = StringBuffer();
    var inBracket = false;
    String? prevBracket;
    for (var i = 0; i < text.length; i++) {
      var c = text[i];
      if (c == '[' || c == '(') {
        if (inBracket) {
          buffer.write(c);
        } else {
          if (buffer.isNotEmpty) {
            words.add(buffer.toString().trim());
            buffer.clear();
          }
          inBracket = true;
          prevBracket = c;
        }
      } else if (c == ']' || c == ')') {
        if (prevBracket == '[' && c == ']' || prevBracket == '(' && c == ')') {
          if (buffer.isNotEmpty) {
            words.add(buffer.toString().trim());
            buffer.clear();
          }
          inBracket = false;
        } else {
          buffer.write(c);
        }
      } else if (c == ',') {
        if (inBracket) {
          buffer.write(c);
        } else {
          words.add(buffer.toString().trim());
          buffer.clear();
        }
      } else {
        buffer.write(c);
      }
    }
    if (buffer.isNotEmpty) {
      words.add(buffer.toString().trim());
    }
    words.removeWhere((element) => element == "");
    words = words.toSet().toList();
    return words;
  }

  void block(BuildContext comicTileContext) {
    showDialog(
      context: App.rootContext,
      builder: (context) {
        var words = <String>[];
        var all = <String>[];
        all.addAll(_splitText(comic.title));
        if (comic.subtitle != null && comic.subtitle != "") {
          all.add(comic.subtitle!);
        }
        all.addAll(comic.tags ?? []);
        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: 'Block'.tl,
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.min(400, context.height - 136),
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    for (var word in all)
                      OptionChip(
                        text: (comic.tags?.contains(word) ?? false)
                            ? word.translateTagIfNeed
                            : word,
                        isSelected: words.contains(word),
                        onTap: () {
                          setState(() {
                            if (!words.contains(word)) {
                              words.add(word);
                            } else {
                              words.remove(word);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ).paddingHorizontal(16),
            ),
            actions: [
              Button.filled(
                onPressed: () {
                  context.pop();
                  for (var word in words) {
                    appdata.settings['blockedWords'].add(word);
                  }
                  appdata.saveData();
                  context.showMessage(message: 'Blocked'.tl);
                  final sliverGridState = comicTileContext
                      .findAncestorStateOfType<_SliverGridComicsState>();
                  final comicListState =
                      comicTileContext.findAncestorStateOfType<ComicListState>();
                  final eInkGridState = comicTileContext
                      .findAncestorStateOfType<_EInkComicGridPagerState>();
                  sliverGridState?.update();
                  comicListState?._onListChanged();
                  eInkGridState?._update();
                },
                child: Text('Block'.tl),
              ),
            ],
          );
        });
      },
    );
  }
}

class _ComicDescription extends StatelessWidget {
  const _ComicDescription({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.enableTranslate,
    this.badge,
    this.maxLines = 2,
    this.tags,
    this.rating,
  });

  final String title;
  final String subtitle;
  final String description;
  final String? badge;
  final List<String>? tags;
  final int maxLines;
  final bool enableTranslate;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    if (tags != null) {
      tags!.removeWhere((element) => element.removeAllBlank == "");
      for (var s in tags!) {
        s = s.replaceAll("\n", " ");
      }
    }
    var enableTranslate =
        App.locale.languageCode == 'zh' && this.enableTranslate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title.trim(),
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14.0,
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
        ),
        if (subtitle != "")
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 10.0,
                color: context.colorScheme.onSurface.toOpacity(0.7)),
            maxLines: 1,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 4),
        if (tags != null && tags!.isNotEmpty)
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxHeight < 22) {
                return Container();
              }
              int cnt = (constraints.maxHeight - 22).toInt() ~/ 25;
              return Container(
                clipBehavior: Clip.antiAlias,
                height: 21 + cnt * 24,
                width: double.infinity,
                decoration: const BoxDecoration(),
                child: Wrap(
                  runAlignment: WrapAlignment.start,
                  clipBehavior: Clip.antiAlias,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 4,
                  runSpacing: 3,
                  children: [
                    for (var s in tags!)
                      Container(
                        height: 21,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.45,
                        ),
                        decoration: BoxDecoration(
                          color: s == "Unavailable"
                              ? context.colorScheme.errorContainer
                              : context.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            enableTranslate
                                ? TagsTranslation.translateTag(s)
                                : s.split(':').last,
                            style: const TextStyle(fontSize: 12),
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ).toAlign(Alignment.topCenter);
            }),
          )
        else
          const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rating != null) StarRating(value: rating!, size: 18),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12.0,
                    ),
                    maxLines: (tags == null || tags!.isEmpty) ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Center(
                  child: Text(
                    "${badge![0].toUpperCase()}${badge!.substring(1).toLowerCase()}",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        )
      ],
    );
  }
}

class _ReadingHistoryPainter extends CustomPainter {
  final int page;
  final int? maxPage;

  const _ReadingHistoryPainter(this.page, this.maxPage);

  @override
  void paint(Canvas canvas, Size size) {
    if (maxPage == null) {
      // 在中央绘制page
      final textPainter = TextPainter(
        text: TextSpan(
          text: "$page",
          style: TextStyle(
            fontSize: size.width * 0.8,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset((size.width - textPainter.width) / 2,
              (size.height - textPainter.height) / 2));
    } else if (page == maxPage) {
      // 在中央绘制勾
      final paint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(size.width * 0.2, size.height * 0.5),
          Offset(size.width * 0.45, size.height * 0.75), paint);
      canvas.drawLine(Offset(size.width * 0.45, size.height * 0.75),
          Offset(size.width * 0.85, size.height * 0.3), paint);
    } else {
      // 在左上角绘制page, 在右下角绘制maxPage
      final textPainter = TextPainter(
        text: TextSpan(
          text: "$page",
          style: TextStyle(
            fontSize: size.width * 0.8,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(0, 0));
      final textPainter2 = TextPainter(
        text: TextSpan(
          text: "/$maxPage",
          style: TextStyle(
            fontSize: size.width * 0.5,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter2.layout();
      textPainter2.paint(
          canvas,
          Offset(size.width - textPainter2.width,
              size.height - textPainter2.height));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _ReadingHistoryPainter ||
        oldDelegate.page != page ||
        oldDelegate.maxPage != maxPage;
  }
}

class SliverGridComics extends StatefulWidget {
  const SliverGridComics(
      {super.key,
      required this.comics,
      this.onLastItemBuild,
      this.badgeBuilder,
      this.menuBuilder,
      this.onTap,
      this.onLongPressed,
      this.selections});

  final List<Comic> comics;

  final Map<Comic, bool>? selections;

  final void Function()? onLastItemBuild;

  final String? Function(Comic)? badgeBuilder;

  final List<MenuEntry> Function(Comic)? menuBuilder;

  final void Function(Comic, int heroID)? onTap;

  final void Function(Comic, int heroID)? onLongPressed;

  @override
  State<SliverGridComics> createState() => _SliverGridComicsState();
}

class _SliverGridComicsState extends State<SliverGridComics> {
  List<Comic> comics = [];
  List<int> heroIDs = [];

  static int _nextHeroID = 0;

  void generateHeroID() {
    heroIDs.clear();
    for (var i = 0; i < comics.length; i++) {
      heroIDs.add(_nextHeroID++);
    }
  }

  @override
  void didUpdateWidget(covariant SliverGridComics oldWidget) {
    if (!comics.isEqualTo(widget.comics)) {
      comics.clear();
      for (var comic in widget.comics) {
        if (isBlocked(comic) == null) {
          comics.add(comic);
        }
      }
      generateHeroID();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    for (var comic in widget.comics) {
      if (isBlocked(comic) == null) {
        comics.add(comic);
      }
    }
    generateHeroID();
    HistoryManager().addListener(update);
    super.initState();
  }

  @override
  void dispose() {
    HistoryManager().removeListener(update);
    super.dispose();
  }

  void update() {
    setState(() {
      comics.clear();
      for (var comic in widget.comics) {
        if (isBlocked(comic) == null) {
          comics.add(comic);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SliverGridComics(
      comics: comics,
      heroIDs: heroIDs,
      selection: widget.selections,
      onLastItemBuild: widget.onLastItemBuild,
      badgeBuilder: widget.badgeBuilder,
      menuBuilder: widget.menuBuilder,
      onTap: widget.onTap,
      onLongPressed: widget.onLongPressed,
    );
  }
}

class _SliverGridComics extends StatelessWidget {
  const _SliverGridComics({
    required this.comics,
    required this.heroIDs,
    this.onLastItemBuild,
    this.badgeBuilder,
    this.menuBuilder,
    this.onTap,
    this.onLongPressed,
    this.selection,
  });

  final List<Comic> comics;

  final List<int> heroIDs;

  final Map<Comic, bool>? selection;

  final void Function()? onLastItemBuild;

  final String? Function(Comic)? badgeBuilder;

  final List<MenuEntry> Function(Comic)? menuBuilder;

  final void Function(Comic, int heroID)? onTap;

  final void Function(Comic, int heroID)? onLongPressed;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == comics.length - 1) {
          onLastItemBuild?.call();
        }
        var badge = badgeBuilder?.call(comics[index]);
        var isSelected = selection == null
            ? false
            : selection![comics[index]] ?? false;
        var comic = ComicTile(
          comic: comics[index],
          badge: badge,
          menuOptions: menuBuilder?.call(comics[index]),
          onTap: onTap != null
              ? () => onTap!(comics[index], heroIDs[index])
              : null,
          onLongPressed: onLongPressed != null
              ? () => onLongPressed!(comics[index], heroIDs[index])
              : null,
          heroID: heroIDs[index],
        );
        if (selection == null) {
          return comic;
        }
        return AnimatedContainer(
          key: ValueKey(comics[index].id),
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(
                    context,
                  ).colorScheme.secondaryContainer.toOpacity(0.72)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(4),
          child: comic,
        );
      }, childCount: comics.length),
      gridDelegate: SliverGridDelegateWithComics(),
    );
  }
}

/// return the first blocked keyword, or null if not blocked
String? isBlocked(Comic item) {
  for (var word in appdata.settings['blockedWords']) {
    if (item.title.contains(word)) {
      return word;
    }
    if (item.subtitle?.contains(word) ?? false) {
      return word;
    }
    if (item.description.contains(word)) {
      return word;
    }
    for (var tag in item.tags ?? <String>[]) {
      if (tag == word) {
        return word;
      }
      if (tag.contains(':')) {
        tag = tag.split(':')[1];
        if (tag == word) {
          return word;
        }
      }
    }
  }
  return null;
}

class _EInkComicGridMetrics {
  const _EInkComicGridMetrics({
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.pageSize,
  });

  final int crossAxisCount;

  final double childAspectRatio;

  final int pageSize;

  factory _EInkComicGridMetrics.fromSize(BuildContext context, Size size) {
    final scale = (appdata.settings['comicTileScale'] as num).toDouble();
    final rawWidth = size.width.isFinite ? size.width : context.width;
    final rawHeight = size.height.isFinite ? size.height : context.height;
    final width = math.max(1.0, rawWidth);
    final height = math.max(1.0, rawHeight - context.padding.bottom);

    if (appdata.settings['comicDisplayMode'] == 'brief') {
      final maxCrossAxisExtent = math.max(80.0, 192.0 * scale);
      final crossAxisCount =
          math.max(1, (width / maxCrossAxisExtent).ceil());
      final itemWidth = width / crossAxisCount;
      final itemHeight = itemWidth / 0.64;
      final rows = math.max(1, height ~/ itemHeight);
      return _EInkComicGridMetrics(
        crossAxisCount: crossAxisCount,
        childAspectRatio: itemWidth / itemHeight,
        pageSize: math.max(1, crossAxisCount * rows),
      );
    }

    final itemHeight = math.max(96.0, 152.0 * scale);
    final crossAxisCount = math.max(1, width ~/ 360.0);
    final itemWidth = width / crossAxisCount;
    final rows = math.max(1, height ~/ itemHeight);
    return _EInkComicGridMetrics(
      crossAxisCount: crossAxisCount,
      childAspectRatio: itemWidth / itemHeight,
      pageSize: math.max(1, crossAxisCount * rows),
    );
  }
}

class _EInkComicGrid extends StatelessWidget {
  const _EInkComicGrid({
    required this.comics,
    required this.metrics,
    this.selections,
    this.badgeBuilder,
    this.menuBuilder,
    this.onTap,
    this.onLongPressed,
    this.heroIDs,
  });

  final List<Comic> comics;

  final _EInkComicGridMetrics metrics;

  final Map<Comic, bool>? selections;

  final String? Function(Comic)? badgeBuilder;

  final List<MenuEntry> Function(Comic)? menuBuilder;

  final void Function(Comic, int heroID)? onTap;

  final void Function(Comic, int heroID)? onLongPressed;

  final List<int>? heroIDs;

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
        final comic = comics[index];
        final heroID = heroIDs?[index] ?? 0;
        final isSelected =
            selections == null ? false : selections![comic] ?? false;
        final comicTile = ComicTile(
          comic: comics[index],
          badge: badgeBuilder?.call(comic),
          menuOptions: menuBuilder?.call(comic),
          onTap: onTap == null ? null : () => onTap!(comic, heroID),
          onLongPressed: onLongPressed == null
              ? null
              : () => onLongPressed!(comic, heroID),
        );
        if (selections == null) {
          return comicTile;
        }
        return Container(
          key: ValueKey(comic.id),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .toOpacity(0.72)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(4),
          child: comicTile,
        );
      },
    );
  }
}

class EInkComicGridPager extends StatefulWidget {
  const EInkComicGridPager({
    super.key,
    required this.comics,
    this.selections,
    this.onLastItemBuild,
    this.badgeBuilder,
    this.menuBuilder,
    this.onTap,
    this.onLongPressed,
  });

  final List<Comic> comics;

  final Map<Comic, bool>? selections;

  final void Function()? onLastItemBuild;

  final String? Function(Comic)? badgeBuilder;

  final List<MenuEntry> Function(Comic)? menuBuilder;

  final void Function(Comic, int heroID)? onTap;

  final void Function(Comic, int heroID)? onLongPressed;

  @override
  State<EInkComicGridPager> createState() => _EInkComicGridPagerState();
}

class _EInkComicGridPagerState extends State<EInkComicGridPager> {
  int _screenPage = 0;

  int _lastScreenPageCount = 1;

  VolumeListener? _volumeListener;

  List<int> _heroIDs = [];

  static int _nextHeroID = 0;

  @override
  void initState() {
    super.initState();
    _generateHeroIDs();
    HistoryManager().addListener(_update);
    appdata.settings.addListener(_update);
    _configureVolumeListener();
  }

  @override
  void didUpdateWidget(covariant EInkComicGridPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.comics.isEqualTo(oldWidget.comics)) {
      _screenPage = 0;
      _generateHeroIDs();
    }
  }

  @override
  void dispose() {
    _volumeListener?.cancel();
    HistoryManager().removeListener(_update);
    appdata.settings.removeListener(_update);
    super.dispose();
  }

  void _generateHeroIDs() {
    _heroIDs = List.generate(widget.comics.length, (_) => _nextHeroID++);
  }

  List<Comic> get _visibleComics => widget.comics
      .where((comic) => isBlocked(comic) == null)
      .toList();

  bool get _canHandleVolumeKey {
    if (!App.isAndroid ||
        appdata.settings['enableTurnPageByVolumeKey'] != true ||
        appdata.settings['eInkMode'] != true) {
      return false;
    }
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  void _configureVolumeListener() {
    final shouldListen = App.isAndroid &&
        appdata.settings['eInkMode'] == true &&
        appdata.settings['enableTurnPageByVolumeKey'] == true;
    if (!shouldListen) {
      _volumeListener?.cancel();
      _volumeListener = null;
      return;
    }
    _volumeListener ??= VolumeListener(
      onDown: () {
        if (_canHandleVolumeKey) {
          _toNextScreenPage();
        }
      },
      onUp: () {
        if (_canHandleVolumeKey) {
          _toPreviousScreenPage();
        }
      },
    )..listen();
  }

  void _update() {
    _configureVolumeListener();
    if (mounted) {
      setState(() {});
    }
  }

  void _toNextScreenPage() {
    if (_screenPage < _lastScreenPageCount - 1) {
      setState(() {
        _screenPage++;
      });
    }
  }

  void _toPreviousScreenPage() {
    if (_screenPage > 0) {
      setState(() {
        _screenPage--;
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -80) {
      _toNextScreenPage();
    } else if (velocity > 80) {
      _toPreviousScreenPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _EInkComicGridMetrics.fromSize(
          context,
          Size(constraints.maxWidth, constraints.maxHeight - 52),
        );
        final comics = _visibleComics;
        final screenPageCount =
            math.max(1, (comics.length / metrics.pageSize).ceil());
        _lastScreenPageCount = screenPageCount;
        if (_screenPage >= screenPageCount) {
          _screenPage = screenPageCount - 1;
        }
        if (_screenPage == screenPageCount - 1) {
          widget.onLastItemBuild?.call();
        }
        final start = _screenPage * metrics.pageSize;
        final end = math.min(start + metrics.pageSize, comics.length);
        final screenComics =
            start >= comics.length ? <Comic>[] : comics.sublist(start, end);
        final screenHeroIDs = start >= _heroIDs.length
            ? <int>[]
            : _heroIDs.sublist(start, math.min(end, _heroIDs.length));

        return Column(
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  FilledButton(
                    onPressed:
                        _screenPage > 0 ? _toPreviousScreenPage : null,
                    child: Text("Back".tl),
                  ).fixWidth(84),
                  Expanded(
                    child: Center(
                      child: Text(
                        "${"Page".tl} ${_screenPage + 1} / $screenPageCount",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: _screenPage < screenPageCount - 1
                        ? _toNextScreenPage
                        : null,
                    child: Text("Next".tl),
                  ).fixWidth(84),
                ],
              ).paddingHorizontal(16),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: _handleDragEnd,
                child: _EInkComicGrid(
                  comics: screenComics,
                  metrics: metrics,
                  selections: widget.selections,
                  badgeBuilder: widget.badgeBuilder,
                  menuBuilder: widget.menuBuilder,
                  onTap: widget.onTap,
                  onLongPressed: widget.onLongPressed,
                  heroIDs: screenHeroIDs,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ComicList extends StatefulWidget {
  const ComicList({
    super.key,
    this.loadPage,
    this.loadNext,
    this.leadingSliver,
    this.trailingSliver,
    this.errorLeading,
    this.menuBuilder,
    this.controller,
    this.refreshHandlerCallback,
    this.enablePageStorage = false,
  });

  final Future<Res<List<Comic>>> Function(int page)? loadPage;

  final Future<Res<List<Comic>>> Function(String? next)? loadNext;

  final Widget? leadingSliver;

  final Widget? trailingSliver;

  final Widget? errorLeading;

  final List<MenuEntry> Function(Comic)? menuBuilder;

  final ScrollController? controller;

  final void Function(VoidCallback c)? refreshHandlerCallback;

  final bool enablePageStorage;

  @override
  State<ComicList> createState() => ComicListState();
}

class ComicListState extends State<ComicList> {
  int? _maxPage;

  final Map<int, List<Comic>> _data = {};

  int _page = 1;

  int _screenPage = 0;

  int _lastScreenPageCount = 1;

  int _lastPageSize = 1;

  String? _error;

  final Map<int, bool> _loading = {};

  String? _nextUrl;

  VolumeListener? _volumeListener;

  late bool enablePageStorage = widget.enablePageStorage;

  Map<String, dynamic> get state => {
        'maxPage': _maxPage,
        'data': _data,
        'page': _page,
        'screenPage': _screenPage,
        'error': _error,
        'loading': _loading,
        'nextUrl': _nextUrl,
      };

  Object get _storageIdentifier => "comic-list-state-${widget.key ?? hashCode}";

  void restoreState(dynamic state) {
    if (state is! Map || !enablePageStorage) {
      return;
    }
    try {
      _maxPage = state['maxPage'] as int?;
      final data = state['data'];
      _data.clear();
      if (data is Map) {
        _data.addAll(data.cast<int, List<Comic>>());
      }
      _page = state['page'] is int ? state['page'] as int : 1;
      _screenPage =
          state['screenPage'] is int ? state['screenPage'] as int : 0;
      _error = state['error'] as String?;
      final loading = state['loading'];
      _loading.clear();
      if (loading is Map) {
        _loading.addAll(loading.cast<int, bool>());
      }
      _nextUrl = state['nextUrl'] as String?;
    } catch (_) {
      _data.clear();
      _loading.clear();
      _page = 1;
      _screenPage = 0;
      _maxPage = null;
      _error = null;
      _nextUrl = null;
    }
  }

  void storeState() {
    if (enablePageStorage) {
      PageStorage.of(context)
          .writeState(context, state, identifier: _storageIdentifier);
    }
  }

  bool get _eInkMode => appdata.settings['eInkMode'] == true;

  @override
  void initState() {
    super.initState();
    HistoryManager().addListener(_onListChanged);
    appdata.settings.addListener(_onSettingsChanged);
    _configureVolumeListener();
  }

  @override
  void dispose() {
    _volumeListener?.cancel();
    HistoryManager().removeListener(_onListChanged);
    appdata.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onListChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onSettingsChanged() {
    _configureVolumeListener();
    if (mounted) {
      setState(() {
        _screenPage = 0;
      });
    }
  }

  bool get _canHandleVolumeKey {
    if (!_eInkMode || !App.isAndroid) {
      return false;
    }
    if (appdata.settings['enableTurnPageByVolumeKey'] != true) {
      return false;
    }
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  void _configureVolumeListener() {
    final shouldListen =
        _eInkMode &&
        App.isAndroid &&
        appdata.settings['enableTurnPageByVolumeKey'] == true;
    if (!shouldListen) {
      _volumeListener?.cancel();
      _volumeListener = null;
      return;
    }
    _volumeListener ??= VolumeListener(
      onDown: () {
        if (_canHandleVolumeKey) {
          _toNextScreenPage();
        }
      },
      onUp: () {
        if (_canHandleVolumeKey) {
          _toPreviousScreenPage();
        }
      },
    )..listen();
  }

  void refresh() {
    _data.clear();
    _page = 1;
    _screenPage = 0;
    _maxPage = null;
    _error = null;
    _nextUrl = null;
    _loading.clear();
    storeState();
    setState(() {});
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
    widget.refreshHandlerCallback?.call(refresh);
  }

  void remove(Comic c) {
    if (_data[_page] == null || !_data[_page]!.remove(c)) {
      for (var page in _data.values) {
        if (page.remove(c)) {
          break;
        }
      }
    }
    setState(() {});
  }

  Widget _buildPageSelector() {
    return Row(
      children: [
        FilledButton(
          onPressed: _page > 1
              ? () {
                  setState(() {
                    _error = null;
                    _page--;
                  });
                }
              : null,
          child: Text("Back".tl),
        ).fixWidth(84),
        Expanded(
          child: Center(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  String value = '';
                  showDialog(
                    context: App.rootContext,
                    builder: (context) {
                      return ContentDialog(
                        title: "Jump to page".tl,
                        content: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Page".tl,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (v) {
                            value = v;
                          },
                        ).paddingHorizontal(16),
                        actions: [
                          Button.filled(
                            onPressed: () {
                              Navigator.of(context).pop();
                              var page = int.tryParse(value);
                              if (page == null) {
                                context.showMessage(message: "Invalid page".tl);
                              } else {
                                if (page > 0 &&
                                    (_maxPage == null || page <= _maxPage!)) {
                                  setState(() {
                                    _error = null;
                                    _page = page;
                                  });
                                } else {
                                  context.showMessage(
                                      message: "Invalid page".tl);
                                }
                              }
                            },
                            child: Text("Jump".tl),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text("Page $_page / ${_maxPage ?? '?'}"),
                ),
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: _page < (_maxPage ?? (_page + 1))
              ? () {
                  setState(() {
                    _error = null;
                    _page++;
                  });
                }
              : null,
          child: Text("Next".tl),
        ).fixWidth(84),
      ],
    ).paddingVertical(8).paddingHorizontal(16);
  }

  Widget _buildSliverPageSelector() {
    return SliverToBoxAdapter(
      child: _buildPageSelector(),
    );
  }

  Future<void> _loadPage(int page) async {
    if (widget.loadPage == null && widget.loadNext == null) {
      _error = "loadPage and loadNext can't be null at the same time";
      Future.microtask(() {
        setState(() {});
      });
    }
    if (_data[page] != null || _loading[page] == true) {
      return;
    }
    _loading[page] = true;
    try {
      if (widget.loadPage != null) {
        var res = await widget.loadPage!(page);
        if (!mounted) return;
        if (res.success) {
          if (res.data.isEmpty) {
            setState(() {
              _data[page] = const [];
              _maxPage ??= page;
            });
          } else {
            setState(() {
              _data[page] = res.data;
              if (res.subData != null && res.subData is int) {
                _maxPage = res.subData;
              }
            });
          }
        } else {
          setState(() {
            _error = res.errorMessage ?? "Unknown error".tl;
          });
        }
      } else {
        try {
          while (_data[page] == null) {
            await _fetchNext();
          }
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _error = e.toString();
            });
          }
        }
      }
    } finally {
      _loading[page] = false;
      storeState();
    }
  }

  Future<void> _fetchNext() async {
    var res = await widget.loadNext!(_nextUrl);
    _data[_data.length + 1] = res.data;
    if (res.subData == null) {
      _maxPage = _data.length;
    } else {
      _nextUrl = res.subData;
    }
  }

  List<Comic> _visibleComics(int page) {
    return (_data[page] ?? const <Comic>[])
        .where((comic) => isBlocked(comic) == null)
        .toList();
  }

  int _lastScreenPageOf(int page) {
    final comics = _visibleComics(page);
    final pageCount = math.max(1, (comics.length / _lastPageSize).ceil());
    return pageCount - 1;
  }

  bool get _canGoToNextNetworkPage => _page < (_maxPage ?? (_page + 1));

  bool get _canGoToPreviousNetworkPage => _page > 1;

  void _toNextScreenPage() {
    if (!mounted) return;
    if (_screenPage < _lastScreenPageCount - 1) {
      setState(() {
        _screenPage++;
      });
      storeState();
    } else if (_canGoToNextNetworkPage) {
      setState(() {
        _error = null;
        _page++;
        _screenPage = 0;
      });
      storeState();
    }
  }

  void _toPreviousScreenPage() {
    if (!mounted) return;
    if (_screenPage > 0) {
      setState(() {
        _screenPage--;
      });
      storeState();
    } else if (_canGoToPreviousNetworkPage) {
      setState(() {
        _error = null;
        _page--;
        _screenPage = _lastScreenPageOf(_page);
      });
      storeState();
    }
  }

  void _handleEInkDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -80) {
      _toNextScreenPage();
    } else if (velocity > 80) {
      _toPreviousScreenPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    var type = appdata.settings['comicListDisplayMode'];
    if (_eInkMode) {
      return buildEInkPagingMode();
    }
    return type == 'paging' ? buildPagingMode() : buildContinuousMode();
  }

  Widget _buildStaticLoading([Widget? leading]) {
    return Column(
      children: [
        if (leading != null) leading,
        Expanded(
          child: Center(
            child: Text("Loading".tl),
          ),
        ),
      ],
    );
  }

  Widget buildEInkPagingMode() {
    if (_error != null) {
      return Column(
        children: [
          if (widget.errorLeading != null) widget.errorLeading!,
          _buildEInkPageSelector(1),
          Expanded(
            child: NetworkError(
              withAppbar: false,
              message: _error!,
              retry: () {
                setState(() {
                  _error = null;
                });
              },
            ),
          ),
        ],
      );
    }
    if (_data[_page] == null) {
      _loadPage(_page);
      return _buildStaticLoading(widget.errorLeading);
    }
    return Column(
      children: [
        if (widget.errorLeading != null) widget.errorLeading!,
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const selectorHeight = 52.0;
              final gridHeight =
                  math.max(1.0, constraints.maxHeight - selectorHeight);
              final metrics = _EInkComicGridMetrics.fromSize(
                context,
                Size(constraints.maxWidth, gridHeight),
              );
              _lastPageSize = metrics.pageSize;

              final comics = _visibleComics(_page);
              final screenPageCount =
                  math.max(1, (comics.length / metrics.pageSize).ceil());
              _lastScreenPageCount = screenPageCount;
              if (_screenPage >= screenPageCount) {
                _screenPage = screenPageCount - 1;
              }
              final start = _screenPage * metrics.pageSize;
              final end = math.min(start + metrics.pageSize, comics.length);
              final screenComics =
                  start >= comics.length ? <Comic>[] : comics.sublist(start, end);

              return Column(
                children: [
                  _buildEInkPageSelector(screenPageCount),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: _handleEInkDragEnd,
                      child: _EInkComicGrid(
                        comics: screenComics,
                        metrics: metrics,
                        menuBuilder: widget.menuBuilder,
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

  Widget _buildEInkPageSelector(int screenPageCount) {
    final canGoBack = _screenPage > 0 || _canGoToPreviousNetworkPage;
    final canGoNext =
        _screenPage < screenPageCount - 1 || _canGoToNextNetworkPage;
    final pageText = _maxPage == null || _maxPage == 1
        ? "${"Page".tl} ${_screenPage + 1} / $screenPageCount"
        : "${"Page".tl} $_page / $_maxPage  -  "
            "${_screenPage + 1} / $screenPageCount";
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          FilledButton(
            onPressed: canGoBack ? _toPreviousScreenPage : null,
            child: Text("Back".tl),
          ).fixWidth(84),
          Expanded(
            child: Center(
              child: Text(
                pageText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          FilledButton(
            onPressed: canGoNext ? _toNextScreenPage : null,
            child: Text("Next".tl),
          ).fixWidth(84),
        ],
      ).paddingHorizontal(16),
    );
  }

  Widget buildPagingMode() {
    if (_error != null) {
      return Column(
        children: [
          if (widget.errorLeading != null) widget.errorLeading!,
          _buildPageSelector(),
          Expanded(
            child: NetworkError(
              withAppbar: false,
              message: _error!,
              retry: () {
                setState(() {
                  _error = null;
                });
              },
            ),
          ),
        ],
      );
    }
    if (_data[_page] == null) {
      _loadPage(_page);
      return Column(
        children: [
          if (widget.errorLeading != null) widget.errorLeading!,
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }
    return SmoothCustomScrollView(
      key: enablePageStorage ? PageStorageKey('scroll$_page') : null,
      controller: widget.controller,
      slivers: [
        if (widget.leadingSliver != null) widget.leadingSliver!,
        if (_maxPage != 1) _buildSliverPageSelector(),
        SliverGridComics(
          comics: _data[_page] ?? const [],
          menuBuilder: widget.menuBuilder,
        ),
        if (_data[_page]!.length > 6 && _maxPage != 1)
          _buildSliverPageSelector(),
        if (widget.trailingSliver != null) widget.trailingSliver!,
      ],
    );
  }

  Widget buildContinuousMode() {
    if (_error != null && _data.isEmpty) {
      return Column(
        children: [
          if (widget.errorLeading != null) widget.errorLeading!,
          _buildPageSelector(),
          Expanded(
            child: NetworkError(
              withAppbar: false,
              message: _error!,
              retry: () {
                setState(() {
                  _error = null;
                });
              },
            ),
          ),
        ],
      );
    }
    if (_data[1] == null) {
      _loadPage(1);
      return Column(
        children: [
          if (widget.errorLeading != null) widget.errorLeading!,
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }
    return SmoothCustomScrollView(
      key: enablePageStorage ? PageStorageKey('scroll$_page') : null,
      controller: widget.controller,
      slivers: [
        if (widget.leadingSliver != null) widget.leadingSliver!,
        SliverGridComics(
          comics: _data.values.expand((element) => element).toList(),
          menuBuilder: widget.menuBuilder,
          onLastItemBuild: () {
            if (_error == null && (_maxPage == null || _data.length < _maxPage!)) {
              _loadPage(_data.length + 1);
            }
          },
        ),
        if (_error != null)
          SliverToBoxAdapter(
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, maxLines: 3)),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                    },
                    child: Text("Retry".tl),
                  ),
                ),
              ],
            ).paddingHorizontal(16).paddingVertical(8),
          )
        else if (_maxPage == null || _data.length < _maxPage!)
          const SliverListLoadingIndicator(),
        if (widget.trailingSliver != null) widget.trailingSliver!,
      ],
    );
  }
}

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.onTap,
    this.size = 20,
  });

  final double value; // 0-5

  final VoidCallback? onTap;

  final double size;

  @override
  Widget build(BuildContext context) {
    var interval = size * 0.1;
    var value = this.value;
    if (value.isNaN) {
      value = 0;
    }
    var child = SizedBox(
      height: size,
      width: size * 5 + interval * 4,
      child: Row(
        children: [
          for (var i = 0; i < 5; i++)
            _Star(
              value: (value - i).clamp(0.0, 1.0),
              size: size,
            ).paddingRight(i == 4 ? 0 : interval),
        ],
      ),
    );
    return onTap == null
        ? child
        : GestureDetector(
            onTap: onTap,
            child: child,
          );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.value, required this.size});

  final double value; // 0-1

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Icon(
            Icons.star_outline,
            size: size,
            color: context.colorScheme.secondary,
          ),
          ClipRect(
            clipper: _StarClipper(value),
            child: Icon(
              Icons.star,
              size: size,
              color: context.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarClipper extends CustomClipper<Rect> {
  final double value;

  _StarClipper(this.value);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * value, size.height);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) {
    return oldClipper is! _StarClipper || oldClipper.value != value;
  }
}

class RatingWidget extends StatefulWidget {
  /// star number
  final int count;

  /// Max score
  final double maxRating;

  /// Current score value
  final double value;

  /// Star size
  final double size;

  /// Space between the stars
  final double padding;

  /// Whether the score can be modified by sliding
  final bool selectable;

  /// Callbacks when ratings change
  final ValueChanged<double> onRatingUpdate;

  const RatingWidget(
      {super.key,
      this.maxRating = 10.0,
      this.count = 5,
      this.value = 10.0,
      this.size = 20,
      required this.padding,
      this.selectable = false,
      required this.onRatingUpdate});

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget> {
  double value = 10;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        double x = event.localPosition.dx;
        if (x < 0) x = 0;
        pointValue(x);
      },
      onPointerMove: (PointerMoveEvent event) {
        double x = event.localPosition.dx;
        if (x < 0) x = 0;
        pointValue(x);
      },
      onPointerUp: (_) {},
      behavior: HitTestBehavior.deferToChild,
      child: buildRowRating(),
    );
  }

  pointValue(double dx) {
    if (!widget.selectable) {
      return;
    }
    if (dx >=
        widget.size * widget.count + widget.padding * (widget.count - 1)) {
      value = widget.maxRating;
    } else {
      for (double i = 1; i < widget.count + 1; i++) {
        if (dx > widget.size * i + widget.padding * (i - 1) &&
            dx < widget.size * i + widget.padding * i) {
          value = i * (widget.maxRating / widget.count);
          break;
        } else if (dx > widget.size * (i - 1) + widget.padding * (i - 1) &&
            dx < widget.size * i + widget.padding * i) {
          value = (dx - widget.padding * (i - 1)) /
              (widget.size * widget.count) *
              widget.maxRating;
          break;
        }
      }
    }
    if (value % 1 >= 0.5) {
      value = value ~/ 1 + 1;
    } else {
      value = (value ~/ 1).toDouble();
    }
    if (value < 0) {
      value = 0;
    } else if (value > 10) {
      value = 10;
    }
    setState(() {
      widget.onRatingUpdate(value);
    });
  }

  int fullStars() {
    return (value / (widget.maxRating / widget.count)).floor();
  }

  double star() {
    if (widget.count / fullStars() == widget.maxRating / value) {
      return 0;
    }
    return (value % (widget.maxRating / widget.count)) /
        (widget.maxRating / widget.count);
  }

  List<Widget> buildRow() {
    int full = fullStars();
    List<Widget> children = [];
    for (int i = 0; i < full; i++) {
      children.add(Icon(
        Icons.star,
        size: widget.size,
        color: context.colorScheme.secondary,
      ));
      if (i < widget.count - 1) {
        children.add(
          SizedBox(
            width: widget.padding,
          ),
        );
      }
    }
    if (full < widget.count) {
      children.add(ClipRect(
        clipper: _SMClipper(rating: star() * widget.size),
        child: Icon(
          Icons.star,
          size: widget.size,
          color: context.colorScheme.secondary,
        ),
      ));
    }

    return children;
  }

  List<Widget> buildNormalRow() {
    List<Widget> children = [];
    for (int i = 0; i < widget.count; i++) {
      children.add(Icon(
        Icons.star_border,
        size: widget.size,
        color: context.colorScheme.secondary,
      ));
      if (i < widget.count - 1) {
        children.add(SizedBox(
          width: widget.padding,
        ));
      }
    }
    return children;
  }

  Widget buildRowRating() {
    return Stack(
      children: <Widget>[
        Row(
          children: buildNormalRow(),
        ),
        Row(
          children: buildRow(),
        )
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    value = widget.value;
  }
}

class _SMClipper extends CustomClipper<Rect> {
  final double rating;

  _SMClipper({required this.rating});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0.0, 0.0, rating, size.height);
  }

  @override
  bool shouldReclip(_SMClipper oldClipper) {
    return rating != oldClipper.rating;
  }
}

class SimpleComicTile extends StatelessWidget {
  const SimpleComicTile(
      {super.key, required this.comic, this.onTap, this.withTitle = false, this.heroID});

  final Comic comic;

  final void Function()? onTap;

  final bool withTitle;

  final int? heroID;

  @override
  Widget build(BuildContext context) {
    var image = _findImageProvider(comic);

    Widget child = image == null
        ? const SizedBox()
        : AnimatedImage(
            image: image,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          );

    child = Container(
      width: 98,
      height: 136,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (heroID != null) {
      child = Hero(
        tag: "cover$heroID",
        child: child,
      );
    }

    child = AnimatedTapRegion(
      borderRadius: 8,
      onTap: onTap ??
          () {
            context.to(
              () => ComicPage(
                id: comic.id,
                sourceKey: comic.sourceKey,
                cover: comic.cover,
                title: comic.title,
                heroID: heroID,
              ),
            );
          },
      child: child,
    );

    if (withTitle) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 4),
          SizedBox(
            width: 92,
            child: Center(
              child: Text(
                comic.title.replaceAll('\n', ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      );
    }

    return child;
  }
}
