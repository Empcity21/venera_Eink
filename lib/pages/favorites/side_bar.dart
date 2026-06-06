part of 'favorites_page.dart';

class _LeftBar extends StatefulWidget {
  const _LeftBar({this.favPage, this.onSelected, this.withAppbar = false});

  final _FavoritesPageState? favPage;

  final VoidCallback? onSelected;

  final bool withAppbar;

  @override
  State<_LeftBar> createState() => _LeftBarState();
}

class _LeftBarState extends State<_LeftBar> implements FolderList {
  late _FavoritesPageState favPage;

  var folders = <String>[];

  var networkFolders = <String>[];

  int _folderPage = 0;

  int _lastFolderPageCount = 1;

  static const _kFolderRowHeight = 56.0;

  void findNetworkFolders() {
    networkFolders.clear();
    var all = ComicSource.all()
        .where((e) => e.favoriteData != null)
        .map((e) => e.favoriteData!.key)
        .toList();
    var settings = appdata.settings['favorites'] as List;
    for (var p in settings) {
      if (all.contains(p) && !networkFolders.contains(p)) {
        networkFolders.add(p);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    favPage = widget.favPage ??
        context.findAncestorStateOfType<_FavoritesPageState>()!;
    favPage.folderList = this;
    folders = LocalFavoritesManager().folderNames;
    findNetworkFolders();
    appdata.settings.addListener(updateFolders);
    LocalFavoritesManager().addListener(updateFolders);
    _configureVolumeListener();
  }

  @override
  void dispose() {
    VolumePageTurnRegistry.unregister(this);
    appdata.settings.removeListener(updateFolders);
    LocalFavoritesManager().removeListener(updateFolders);
    super.dispose();
  }

  bool get _eInkMode => appdata.settings['eInkMode'] == true;

  bool get _canHandleVolumeKey {
    if (!widget.withAppbar || !_eInkMode || !App.isAndroid) {
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
    final shouldListen = widget.withAppbar &&
        _eInkMode &&
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
        _toNextFolderPage();
      },
      onUp: () {
        _toPreviousFolderPage();
      },
    );
  }

  void _toNextFolderPage() {
    if (_folderPage >= _lastFolderPageCount - 1) {
      return;
    }
    setState(() {
      _folderPage++;
    });
  }

  void _toPreviousFolderPage() {
    if (_folderPage <= 0) {
      return;
    }
    setState(() {
      _folderPage--;
    });
  }

  void _handleEInkDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -80) {
      _toNextFolderPage();
    } else if (velocity > 80) {
      _toPreviousFolderPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: context.colorScheme.outlineVariant,
            width: 0.6,
          ),
        ),
      ),
      child: Column(
        children: [
          if (widget.withAppbar)
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const CloseButton(),
                  const SizedBox(width: 8),
                  Text(
                    "Folders".tl,
                    style: ts.s18,
                  ),
                ],
              ),
            ).paddingTop(context.padding.top),
          Expanded(
            child: _eInkMode ? buildEInkFolderList() : buildScrollableFolderList(),
          )
        ],
      ),
    );
  }

  Widget buildScrollableFolderList() {
    return ListView.builder(
      padding: widget.withAppbar
          ? EdgeInsets.zero
          : EdgeInsets.only(top: context.padding.top),
      itemCount: folders.length + networkFolders.length + 3,
      itemBuilder: (context, index) {
        if (index == 0) {
          return buildLocalTitle();
        }
        index--;
        if (index == 0) {
          return buildLocalFolder(_localAllFolderLabel);
        }
        index--;
        if (index < folders.length) {
          return buildLocalFolder(folders[index]);
        }
        index -= folders.length;
        if (index == 0) {
          return buildNetworkTitle();
        }
        index--;
        return buildNetworkFolder(networkFolders[index]);
      },
    );
  }

  List<Widget> buildFolderItems() {
    return [
      buildLocalTitle(),
      buildLocalFolder(_localAllFolderLabel),
      for (final folder in folders) buildLocalFolder(folder),
      buildNetworkTitle(),
      for (final folder in networkFolders) buildNetworkFolder(folder),
    ];
  }

  Widget buildEInkFolderList() {
    final topPadding = widget.withAppbar ? 0.0 : context.padding.top;
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const selectorHeight = 52.0;
          final items = buildFolderItems();
          final listHeight = max(1.0, constraints.maxHeight - selectorHeight);
          final itemsPerPage =
              max(1, (listHeight / _kFolderRowHeight).floor());
          final pageCount = max(1, (items.length / itemsPerPage).ceil());
          _lastFolderPageCount = pageCount;
          if (_folderPage >= pageCount) {
            _folderPage = pageCount - 1;
          }
          final start = _folderPage * itemsPerPage;
          final end = min(start + itemsPerPage, items.length);
          final pageItems =
              start >= items.length ? const <Widget>[] : items.sublist(start, end);

          return Column(
            children: [
              buildEInkPageSelector(pageCount),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: _handleEInkDragEnd,
                  child: Column(
                    children: [
                      for (final item in pageItems)
                        SizedBox(
                          height: _kFolderRowHeight,
                          child: item,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildEInkPageSelector(int pageCount) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          FilledButton(
            onPressed: _folderPage > 0 ? _toPreviousFolderPage : null,
            child: Text("Back".tl),
          ).fixWidth(84),
          Expanded(
            child: Center(
              child: Text(
                "${"Page".tl} ${_folderPage + 1} / $pageCount",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          FilledButton(
            onPressed:
                _folderPage < pageCount - 1 ? _toNextFolderPage : null,
            child: Text("Next".tl),
          ).fixWidth(84),
        ],
      ).paddingHorizontal(12),
    );
  }

  Widget buildLocalTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.local_activity,
            color: context.colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          Text("Local".tl),
          const Spacer(),
          MenuButton(
            entries: [
              MenuEntry(
                icon: Icons.add,
                text: 'Create Folder'.tl,
                onClick: () {
                  newFolder().then((value) {
                    setState(() {
                      folders = LocalFavoritesManager().folderNames;
                    });
                  });
                },
              ),
              MenuEntry(
                icon: Icons.reorder,
                text: 'Sort'.tl,
                onClick: () {
                  sortFolders().then((value) {
                    setState(() {
                      folders = LocalFavoritesManager().folderNames;
                    });
                  });
                },
              ),
            ],
          ),
        ],
      ).paddingHorizontal(16),
    );
  }

  Widget buildNetworkTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.colorScheme.outlineVariant,
            width: 0.6,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud,
            color: context.colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          Text("Network".tl),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showPopUpWidget(
                App.rootContext,
                setFavoritesPagesWidget(),
              );
            },
          ),
        ],
      ).paddingHorizontal(16),
    );
  }

  Widget buildLocalFolder(String name) {
    bool isSelected = name == favPage.folder && !favPage.isNetwork;
    int count = 0;
    if (name == _localAllFolderLabel) {
      count = LocalFavoritesManager().totalComics;
    } else {
      count = LocalFavoritesManager().folderComics(name);
    }
    var folderName = name == _localAllFolderLabel
        ? "All".tl
        : getFavoriteDataOrNull(name)?.title ?? name;
    return InkWell(
      onTap: () {
        if (isSelected) {
          return;
        }
        favPage.setFolder(false, name);
        widget.onSelected?.call();
      },
      child: Container(
        height: 42,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primaryContainer.toOpacity(0.36)
              : null,
          border: Border(
            left: BorderSide(
              color:
                  isSelected ? context.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(folderName),
            ),
            Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(count.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNetworkFolder(String key) {
    var data = getFavoriteDataOrNull(key);
    if (data == null) {
      return const SizedBox();
    }
    bool isSelected = key == favPage.folder && favPage.isNetwork;
    return InkWell(
      onTap: () {
        if (isSelected) {
          return;
        }
        favPage.setFolder(true, key);
        widget.onSelected?.call();
      },
      child: Container(
        height: 42,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primaryContainer.toOpacity(0.36)
              : null,
          border: Border(
            left: BorderSide(
              color:
                  isSelected ? context.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Text(data.title),
      ),
    );
  }

  @override
  void update() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void updateFolders() {
    if (!mounted) return;
    _configureVolumeListener();
    setState(() {
      folders = LocalFavoritesManager().folderNames;
      findNetworkFolders();
      if (_folderPage >= _lastFolderPageCount) {
        _folderPage = max(0, _lastFolderPageCount - 1);
      }
    });
  }
}
