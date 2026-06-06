part of 'favorites_page.dart';

Future<bool> _deleteComic(
  String cid,
  String? fid,
  String sourceKey,
  String? favId,
) async {
  var source = ComicSource.find(sourceKey);
  if (source == null) {
    return false;
  }

  var result = false;

  await showDialog(
    context: App.rootContext,
    builder: (context) {
      bool loading = false;
      return StatefulBuilder(builder: (context, setState) {
        return ContentDialog(
          title: "Remove".tl,
          content: Text("Remove comic from favorite?".tl).paddingHorizontal(16),
          actions: [
            Button.filled(
              isLoading: loading,
              color: context.colorScheme.error,
              onPressed: () async {
                setState(() {
                  loading = true;
                });
                var res = await source.favoriteData!.addOrDelFavorite!(
                  cid,
                  fid ?? '',
                  false,
                  favId,
                );
                if (res.success) {
                  // Invalidate network cache so next loads fetch fresh data
                  NetworkCacheManager().clear();
                  context.showMessage(message: "Deleted".tl);
                  result = true;
                  context.pop();
                } else {
                  setState(() {
                    loading = false;
                  });
                  context.showMessage(message: res.errorMessage!);
                }
              },
              child: Text("Confirm".tl),
            ),
          ],
        );
      });
    },
  );

  return result;
}

class NetworkFavoritePage extends StatelessWidget {
  const NetworkFavoritePage(this.data, {super.key});

  final FavoriteData data;

  @override
  Widget build(BuildContext context) {
    return data.multiFolder
        ? _MultiFolderFavoritesPage(data)
        : _NormalFavoritePage(data);
  }
}

class _NormalFavoritePage extends StatefulWidget {
  const _NormalFavoritePage(this.data);

  final FavoriteData data;

  @override
  State<_NormalFavoritePage> createState() => _NormalFavoritePageState();
}

class _NormalFavoritePageState extends State<_NormalFavoritePage> {
  final comicListKey = GlobalKey<ComicListState>();

  void showFolders() {
    context
        .findAncestorStateOfType<_FavoritesPageState>()!
        .showFolderSelector();
  }

  @override
  Widget build(BuildContext context) {
    return ComicList(
      key: comicListKey,
      leadingSliver: SliverAppbar(
        style:
            context.width < changePoint ? AppbarStyle.shadow : AppbarStyle.blur,
        leading: Tooltip(
          message: "Folders".tl,
          child: context.width <= _kTwoPanelChangeWidth
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  color: context.colorScheme.primary,
                  onPressed: showFolders,
                )
              : null,
        ),
        title: GestureDetector(
          onTap: context.width < _kTwoPanelChangeWidth ? showFolders : null,
          child: Text(widget.data.title),
        ),
        actions: [
          Tooltip(
            message: "Refresh".tl,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Force refresh bypassing cache
                NetworkCacheManager().clear();
                comicListKey.currentState!.refresh();
              },
            ),
          ),
          MenuButton(entries: [
            MenuEntry(
              icon: Icons.sync,
              text: "Convert to local".tl,
              onClick: () {
                importNetworkFolder(widget.data.key, 9999999, null, null);
              },
            )
          ]),
        ],
      ),
      errorLeading: Appbar(
        leading: Tooltip(
          message: "Folders".tl,
          child: context.width <= _kTwoPanelChangeWidth
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  color: context.colorScheme.primary,
                  onPressed: context
                      .findAncestorStateOfType<_FavoritesPageState>()!
                      .showFolderSelector,
                )
              : null,
        ),
        title: GestureDetector(
          onTap: context.width < _kTwoPanelChangeWidth ? showFolders : null,
          child: Text(widget.data.title),
        ),
      ),
      loadPage: widget.data.loadComic == null
          ? null
          : (i) => widget.data.loadComic!(i),
      loadNext: widget.data.loadNext == null
          ? null
          : (next) => widget.data.loadNext!(next),
      menuBuilder: (comic) {
        return [
          MenuEntry(
            icon: Icons.delete_outline,
            text: "Remove".tl,
            onClick: () async {
              var res = await _deleteComic(
                comic.id,
                null,
                comic.sourceKey,
                comic.favoriteId,
              );
              if (res) {
                comicListKey.currentState!.remove(comic);
              }
            },
          ),
        ];
      },
      enablePageStorage: true,
    );
  }
}

class _MultiFolderFavoritesPage extends StatefulWidget {
  const _MultiFolderFavoritesPage(this.data);

  final FavoriteData data;

  @override
  State<_MultiFolderFavoritesPage> createState() =>
      _MultiFolderFavoritesPageState();
}

class _MultiFolderFavoritesPageState extends State<_MultiFolderFavoritesPage> {
  bool _loading = true;

  String? _errorMessage;

  Map<String, String>? folders;

  int _folderPage = 0;

  int _lastFolderPageCount = 1;

  VolumeListener? _volumeListener;

  static const _kFolderTileHeight = 56.0;

  @override
  void initState() {
    super.initState();
    appdata.settings.addListener(_onSettingsChanged);
    _configureVolumeListener();
  }

  @override
  void dispose() {
    _volumeListener?.cancel();
    appdata.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  bool get _eInkMode => appdata.settings['eInkMode'] == true;

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
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  void _configureVolumeListener() {
    final shouldListen = _eInkMode &&
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
          _toNextFolderPage();
        }
      },
      onUp: () {
        if (_canHandleVolumeKey) {
          _toPreviousFolderPage();
        }
      },
    )..listen();
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

  void showFolders() {
    context
        .findAncestorStateOfType<_FavoritesPageState>()!
        .showFolderSelector();
  }

  void loadPage() async {
    var res = await widget.data.loadFolders!();
    if (!mounted) {
      return;
    }
    _loading = false;
    if (res.error) {
      setState(() {
        _errorMessage = res.errorMessage;
      });
    } else {
      setState(() {
        folders = res.data;
      });
    }
  }

  void openFolder(String key, String title) {
    context.to(() => _FavoriteFolder(widget.data, key, title));
  }

  void showCreateFolderDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _CreateFolderDialog(
          widget.data,
          () => setState(() {
            _loading = true;
            _folderPage = 0;
          }),
        );
      },
    );
  }

  List<Widget> buildFolderItems() {
    final keys = folders!.keys.toList();
    return [
      if (widget.data.allFavoritesId != null)
        _FolderTile(
          name: "All".tl,
          onTap: () => openFolder(widget.data.allFavoritesId!, "All".tl),
        ),
      for (final key in keys)
        _FolderTile(
          name: folders![key]!,
          onTap: () => openFolder(key, folders![key]!),
          deleteFolder: widget.data.deleteFolder == null
              ? null
              : () => widget.data.deleteFolder!(key),
          updateState: () => setState(() {
            _loading = true;
            _folderPage = 0;
          }),
        ),
      if (widget.data.addFolder != null) buildCreateFolderTile(),
    ];
  }

  Widget buildCreateFolderTile() {
    return Material(
      child: InkWell(
        onTap: showCreateFolderDialog,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Create a folder".tl),
              const SizedBox(width: 8),
              const Icon(Icons.add, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildEInkFoldersPage(Appbar appBar) {
    final items = buildFolderItems();
    return Column(
      children: [
        appBar,
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const selectorHeight = 52.0;
              final listHeight =
                  max(1.0, constraints.maxHeight - selectorHeight);
              final itemsPerPage =
                  max(1, (listHeight / _kFolderTileHeight).floor());
              final pageCount =
                  max(1, (items.length / itemsPerPage).ceil());
              _lastFolderPageCount = pageCount;
              if (_folderPage >= pageCount) {
                _folderPage = pageCount - 1;
              }
              final start = _folderPage * itemsPerPage;
              final end = min(start + itemsPerPage, items.length);
              final pageItems = start >= items.length
                  ? const <Widget>[]
                  : items.sublist(start, end);

              return Column(
                children: [
                  buildEInkPageSelector(pageCount),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: _handleEInkDragEnd,
                      child: pageItems.isEmpty
                          ? Center(child: Text("Empty Page".tl))
                          : Column(
                              children: [
                                for (final item in pageItems)
                                  SizedBox(
                                    height: _kFolderTileHeight,
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
        ),
      ],
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
      ).paddingHorizontal(16),
    );
  }

  @override
  Widget build(BuildContext context) {
    var sliverAppBar = SliverAppbar(
      style:
          context.width < changePoint ? AppbarStyle.shadow : AppbarStyle.blur,
      leading: Tooltip(
        message: "Folders".tl,
        child: context.width <= _kTwoPanelChangeWidth
            ? IconButton(
                icon: const Icon(Icons.menu),
                color: context.colorScheme.primary,
                onPressed: showFolders,
              )
            : null,
      ),
      title: GestureDetector(
        onTap: context.width < _kTwoPanelChangeWidth ? showFolders : null,
        child: Text(widget.data.title),
      ),
    );

    var appBar = Appbar(
      leading: Tooltip(
        message: "Folders".tl,
        child: context.width <= _kTwoPanelChangeWidth
            ? IconButton(
                icon: const Icon(Icons.menu),
                color: context.colorScheme.primary,
                onPressed: showFolders,
              )
            : null,
      ),
      title: GestureDetector(
        onTap: context.width < _kTwoPanelChangeWidth ? showFolders : null,
        child: Text(widget.data.title),
      ),
    );

    if (_loading) {
      loadPage();
      return Column(
        children: [
          appBar,
          Expanded(
            child: Center(
              child: _eInkMode
                  ? Text("Loading".tl)
                  : const CircularProgressIndicator(),
            ),
          ),
        ],
      );
    } else if (_errorMessage != null) {
      return Column(
        children: [
          appBar,
          Expanded(
            child: NetworkError(
              message: _errorMessage!,
              withAppbar: false,
              retry: () {
                setState(() {
                  _loading = true;
                  _errorMessage = null;
                });
              },
            ),
          )
        ],
      );
    } else {
      if (_eInkMode) {
        return buildEInkFoldersPage(appBar);
      }
      var length = folders!.length;
      if (widget.data.allFavoritesId != null) length++;
      final keys = folders!.keys.toList();

      return SmoothCustomScrollView(
        slivers: [
          sliverAppBar,
          SliverGridViewWithFixedItemHeight(
            delegate:
                SliverChildBuilderDelegate(childCount: length, (context, i) {
              if (widget.data.allFavoritesId != null) {
                if (i == 0) {
                  return _FolderTile(
                      name: "All".tl,
                      onTap: () =>
                          openFolder(widget.data.allFavoritesId!, "All".tl));
                } else {
                  i--;
                  return _FolderTile(
                    name: folders![keys[i]]!,
                    onTap: () => openFolder(keys[i], folders![keys[i]]!),
                    deleteFolder: widget.data.deleteFolder == null
                        ? null
                        : () => widget.data.deleteFolder!(keys[i]),
                    updateState: () => setState(() {
                      _loading = true;
                    }),
                  );
                }
              } else {
                return _FolderTile(
                  name: folders![keys[i]]!,
                  onTap: () => openFolder(keys[i], folders![keys[i]]!),
                  deleteFolder: widget.data.deleteFolder == null
                      ? null
                      : () => widget.data.deleteFolder!(keys[i]),
                  updateState: () => setState(() {
                    _loading = true;
                  }),
                );
              }
            }),
            maxCrossAxisExtent: 450,
            itemHeight: 52,
          ),
          if (widget.data.addFolder != null)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60,
                width: double.infinity,
                child: Center(
                  child: TextButton(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Create a folder".tl),
                        const Icon(
                          Icons.add,
                          size: 18,
                        ),
                      ],
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return _CreateFolderDialog(
                            widget.data,
                            () => setState(() {
                              _loading = true;
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            )
        ],
      );
    }
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile(
      {required this.name,
      required this.onTap,
      this.deleteFolder,
      this.updateState});

  final String name;

  final Future<Res<bool>> Function()? deleteFolder;

  final void Function()? updateState;

  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.folder,
                size: 28,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(
                width: 16,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              if (deleteFolder != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDeleteFolder(context),
                )
              else
                const Icon(Icons.arrow_right),
            ],
          ),
        ),
      ),
    );
  }

  void onDeleteFolder(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        bool loading = false;
        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: "Delete".tl,
            content: Text("Delete folder?".tl).paddingHorizontal(16),
            actions: [
              Button.filled(
                isLoading: loading,
                color: context.colorScheme.error,
                onPressed: () async {
                  setState(() {
                    loading = true;
                  });
                  var res = await deleteFolder!();
                  if (res.success) {
                    context.showMessage(message: "Deleted".tl);
                    context.pop();
                    updateState?.call();
                  } else {
                    setState(() {
                      loading = false;
                    });
                    context.showMessage(message: res.errorMessage!);
                  }
                },
                child: Text("Confirm".tl),
              ),
            ],
          );
        });
      },
    );
  }
}

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog(this.data, this.updateState);

  final FavoriteData data;

  final void Function() updateState;

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  var controller = TextEditingController();
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: "Create a folder".tl,
      content: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: "name".tl,
              ),
            ),
          ),
          const SizedBox(
            height: 16
          ),
        ],
      ),
      actions: [
        Button.filled(
          isLoading: loading,
          onPressed: () {
            setState(() {
              loading = true;
            });
            widget.data.addFolder!(controller.text).then((b) {
              if (b.error) {
                context.showMessage(message: b.errorMessage!);
                setState(() {
                  loading = false;
                });
              } else {
                context.pop();
                context.showMessage(message: "Created successfully".tl);
                widget.updateState();
              }
            });
          },
          child: Text("Submit".tl),
        )
      ],
    );
  }
}

class _FavoriteFolder extends StatelessWidget {
  _FavoriteFolder(this.data, this.folderID, this.title);

  final FavoriteData data;

  final String folderID;

  final String title;

  final comicListKey = GlobalKey<ComicListState>();

  @override
  Widget build(BuildContext context) {
    return ComicList(
      key: comicListKey,
      enablePageStorage: true,
      leadingSliver: SliverAppbar(
        title: Text(title),
        actions: [
          MenuButton(entries: [
            MenuEntry(
              icon: Icons.sync,
              text: "Convert to local".tl,
              onClick: () {
                importNetworkFolder(data.key, 9999999, title, folderID);
              },
            )
          ]),
        ],
      ),
      errorLeading: Appbar(
        title: Text(title),
      ),
      loadPage:
          data.loadComic == null ? null : (i) => data.loadComic!(i, folderID),
      loadNext: data.loadNext == null
          ? null
          : (next) => data.loadNext!(next, folderID),
      menuBuilder: (comic) {
        return [
          MenuEntry(
            icon: Icons.delete_outline,
            text: "Remove".tl,
            onClick: () async {
              var res = await _deleteComic(
                comic.id,
                null,
                comic.sourceKey,
                comic.favoriteId,
              );
              if (res) {
                comicListKey.currentState!.remove(comic);
              }
            },
          ),
        ];
      },
    );
  }
}
