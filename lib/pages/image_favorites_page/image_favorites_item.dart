part of 'image_favorites_page.dart';

class _ImageFavoritesItem extends StatefulWidget {
  const _ImageFavoritesItem({
    super.key,
    required this.imageFavoritesComic,
    required this.selectedImageFavorites,
    required this.addSelected,
    required this.multiSelectMode,
    required this.finalImageFavoritesComicList,
  });

  final ImageFavoritesComic imageFavoritesComic;
  final Function(ImageFavorite) addSelected;
  final Map<ImageFavorite, bool> selectedImageFavorites;
  final List<ImageFavoritesComic> finalImageFavoritesComicList;
  final bool multiSelectMode;

  @override
  State<_ImageFavoritesItem> createState() => _ImageFavoritesItemState();
}

class _ImageFavoritesItemState extends State<_ImageFavoritesItem> {
  List<ImageFavorite> get imageFavorites =>
      widget.imageFavoritesComic.images.toList();

  void goComicInfo(ImageFavoritesComic comic) {
    App.mainNavigatorKey?.currentContext?.to(() => ComicPage(
          id: comic.id,
          sourceKey: comic.sourceKey,
        ));
  }

  void goReaderPage(ImageFavoritesComic comic, int ep, int page) {
    App.rootContext.to(
      () => ReaderWithLoading(
        id: comic.id,
        sourceKey: comic.sourceKey,
        initialEp: ep,
        initialPage: page,
      ),
    );
  }

  void goPhotoView(ImageFavorite imageFavorite) {
    Navigator.of(App.rootContext).push(MaterialPageRoute(
        builder: (context) => ImageFavoritesPhotoView(
              comic: widget.imageFavoritesComic,
              imageFavorite: imageFavorite,
            )));
  }

  void copyTitle() {
    Clipboard.setData(ClipboardData(text: widget.imageFavoritesComic.title));
    App.rootContext.showMessage(message: 'Copy the title successfully'.tl);
  }

  void onLongPress() {
    var renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var location = renderBox.localToGlobal(
      Offset((size.width - 242) / 2, size.height / 2),
    );
    showMenu(location, context);
  }

  void onSecondaryTap(TapDownDetails details) {
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
            goComicInfo(widget.imageFavoritesComic);
          },
        ),
        MenuEntry(
          icon: Icons.copy,
          text: 'Copy Title'.tl,
          onClick: () {
            copyTitle();
          },
        ),
        MenuEntry(
          icon: Icons.select_all,
          text: 'Select All'.tl,
          onClick: () {
            for (var ele in widget.imageFavoritesComic.images) {
              widget.addSelected(ele);
            }
          },
        ),
        MenuEntry(
          icon: Icons.read_more,
          text: 'Photo View'.tl,
          onClick: () {
            goPhotoView(widget.imageFavoritesComic.images.first);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onSecondaryTapDown: onSecondaryTap,
        onLongPress: onLongPress,
        onTap: () {
          if (widget.multiSelectMode) {
            for (var ele in widget.imageFavoritesComic.images) {
              widget.addSelected(ele);
            }
          } else {
            // 单击跳转漫画详情
            goComicInfo(widget.imageFavoritesComic);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildTop(),
            SizedBox(
              height: 145,
              child: appdata.settings['eInkMode'] == true
                  ? _EInkImageFavoriteStrip(
                      itemCount: imageFavorites.length,
                      itemBuilder: buildItem,
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: buildItem,
                      itemCount: imageFavorites.length,
                    ),
            ).paddingHorizontal(8),
            buildBottom(),
          ],
        ),
      ),
    );
  }

  Widget buildItem(BuildContext context, int index) {
    var image = imageFavorites[index];
    bool isSelected = widget.selectedImageFavorites[image] ?? false;
    int curPage = image.page;
    String pageText = curPage == firstPage
        ? '@a Cover'.tlParams({"a": image.epName})
        : curPage.toString();

    return InkWell(
      onTap: () {
        // 单击去阅读页面, 跳转到当前点击的page
        if (widget.multiSelectMode) {
          widget.addSelected(image);
        } else {
          goReaderPage(widget.imageFavoritesComic, image.ep, curPage);
        }
      },
      onLongPress: () {
        goPhotoView(image);
      },
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 106,
        height: 145,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.secondaryContainer,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Hero(
                    tag: "${image.sourceKey}${image.ep}${image.page}",
                    child: AnimatedImage(
                      image: ImageFavoritesProvider(image),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 15,
                child: Text(
                  pageText,
                  style: ts.s10,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            ],
          ),
        ),
      ),
    ).paddingHorizontal(4);
  }

  Widget buildTop() {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.imageFavoritesComic.title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16.0,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
              "${imageFavorites.length}/${widget.imageFavoritesComic.maxPageFromEp}",
              style: ts.s12),
        ),
      ],
    ).paddingHorizontal(16).paddingVertical(8);
  }

  Widget buildBottom() {
    var enableTranslate = App.locale.languageCode == 'zh';
    String time =
        DateFormat('yyyy-MM-dd').format(widget.imageFavoritesComic.time);
    List<String> tags = [];
    for (var tag in widget.imageFavoritesComic.tags) {
      var text = enableTranslate ? tag.translateTagsToCN : tag;
      if (text.contains(':')) {
        text = text.split(':').last;
      }
      tags.add(text);
      if (tags.length == 5) {
        break;
      }
    }
    var comicSource = ComicSource.find(widget.imageFavoritesComic.sourceKey);
    return Row(
      children: [
        Text(
          "$time | ${comicSource?.name ?? "Unknown"}",
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontSize: 12.0,
          ),
        ).paddingRight(8),
        if (tags.isNotEmpty)
          Expanded(
            child: Text(
              tags
                  .map((e) => enableTranslate ? e.translateTagsToCN : e)
                  .join(" "),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.0,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
      ],
    ).paddingHorizontal(8).paddingBottom(8);
  }
}

class _EInkImageFavoriteStrip extends StatefulWidget {
  const _EInkImageFavoriteStrip({
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;

  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  State<_EInkImageFavoriteStrip> createState() => _EInkImageFavoriteStripState();
}

class _EInkImageFavoriteStripState extends State<_EInkImageFavoriteStrip> {
  int _page = 0;

  @override
  void didUpdateWidget(covariant _EInkImageFavoriteStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      _page = 0;
    }
  }

  void _toNextPage(int pageCount) {
    if (_page >= pageCount - 1) {
      return;
    }
    setState(() {
      _page++;
    });
  }

  void _toPreviousPage() {
    if (_page <= 0) {
      return;
    }
    setState(() {
      _page--;
    });
  }

  void _handleDragEnd(DragEndDetails details, int pageCount) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -80) {
      _toNextPage(pageCount);
    } else if (velocity > 80) {
      _toPreviousPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemWidth = 114.0;
        final itemsPerPage =
            math.max(1, constraints.maxWidth ~/ itemWidth);
        final pageCount =
            math.max(1, (widget.itemCount / itemsPerPage).ceil());
        if (_page >= pageCount) {
          _page = pageCount - 1;
        }
        final start = _page * itemsPerPage;
        final end = math.min(start + itemsPerPage, widget.itemCount);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) => _handleDragEnd(details, pageCount),
          child: Stack(
            children: [
              Row(
                children: [
                  for (var i = start; i < end; i++)
                    widget.itemBuilder(context, i),
                ],
              ),
              if (_page > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _toPreviousPage,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: "Back".tl,
                  ),
                ),
              if (_page < pageCount - 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => _toNextPage(pageCount),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: "Next".tl,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
