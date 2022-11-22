import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:listar_flutter_pro/blocs/bloc.dart';
import 'package:listar_flutter_pro/configs/config.dart';
import 'package:listar_flutter_pro/models/model.dart';
import 'package:listar_flutter_pro/repository/repository.dart';
import 'package:listar_flutter_pro/screens/profile/profile_header.dart';
import 'package:listar_flutter_pro/screens/profile/profile_tab.dart';
import 'package:listar_flutter_pro/utils/utils.dart';
import 'package:listar_flutter_pro/widgets/widget.dart';
import 'package:share/share.dart';

class Profile extends StatefulWidget {
  final UserModel user;
  const Profile({Key? key, required this.user}) : super(key: key);

  @override
  _ProfileState createState() {
    return _ProfileState();
  }
}

class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  late StreamSubscription _submitSubscription;
  late StreamSubscription _reviewSubscription;
  final _profileCubit = ProfileCubit();
  final _scrollController = ScrollController();
  final _textSearchController = TextEditingController();
  final _endReachedThreshold = 100;

  bool _isOwner = false;
  FilterModel _filter = FilterModel.fromDefault();
  TabController? _tabController;
  int _indexTab = 0;
  UserModel? user;

  @override
  void initState() {
    super.initState();
    _isOwner = widget.user.id == AppBloc.userCubit.state?.id;
    _tabController = TabController(length: _isOwner ? 3 : 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _submitSubscription = AppBloc.submitCubit.stream.listen((state) {
      if (state is Submitted) {
        _onRefresh();
      }
    });
    _reviewSubscription = AppBloc.reviewCubit.stream.listen((state) {
      if (state is ReviewSuccess && state.id != null) {
        _onRefresh();
      }
    });
    _onRefresh();
  }

  @override
  void dispose() {
    _submitSubscription.cancel();
    _reviewSubscription.cancel();
    _profileCubit.close();
    _scrollController.dispose();
    _textSearchController.dispose();
    super.dispose();
  }

  ///On Refresh
  Future<void> _onRefresh() async {
    _profileCubit.onLoad(
      filter: _filter,
      keyword: _textSearchController.text,
      userID: widget.user.id,
      indexTab: _indexTab,
    );
  }

  ///Handle load more
  void _onScroll() {
    if (_scrollController.position.extentAfter > _endReachedThreshold) return;
    final state = _profileCubit.state;
    if (state is ProfileSuccess && state.canLoadMore && !state.loadingMore) {
      _profileCubit.onLoadMore(
        filter: _filter,
        keyword: _textSearchController.text,
        userID: widget.user.id,
        indexTab: _indexTab,
      );
    }
  }

  ///On Change Tab
  void _onTap(int index) {
    setState(() {
      _indexTab = index;
    });
    _onRefresh();
  }

  ///On Search
  void _onSearch(String text) {
    _profileCubit.onSearch(
      filter: _filter,
      keyword: _textSearchController.text,
      userID: widget.user.id,
      indexTab: _indexTab,
    );
  }

  ///On Preview Profile
  void _onProfile(UserModel user) {
    Navigator.pushNamed(context, Routes.profile, arguments: user);
  }

  ///On Scan QR
  void _onQRCode() async {
    final result = await Navigator.pushNamed(
      context,
      Routes.profileQRCode,
      arguments: widget.user,
    );
    if (result != null && result is UserModel) {
      await Future.delayed(const Duration(milliseconds: 500));
      _onProfile(result);
    }
  }

  ///On change filter
  void _onFilter() async {
    final result = await Navigator.pushNamed(
      context,
      Routes.filter,
      arguments: _filter.clone(),
    );
    if (result != null && result is FilterModel) {
      setState(() {
        _filter = result;
      });
      _onRefresh();
    }
  }

  ///On Change Sort
  void _onSort() async {
    final result = await showModalBottomSheet<SortModel?>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return AppBottomPicker(
          picker: PickerModel(
            selected: [_filter.sort],
            data: Application.setting.sort,
          ),
        );
      },
    );
    if (result != null) {
      _filter.sort = result;
      _onRefresh();
    }
  }

  ///Action Item
  void _onSheetAction(ProductModel item) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        Widget bookingItem = Container();
        Widget editItem = Container();
        Widget removeItem = Container();
        if (item.bookingUse) {
          bookingItem = AppListTitle(
            title: Translate.of(context).translate("booking"),
            leading: const Icon(Icons.pending_actions_outlined),
            onPressed: () {
              Navigator.pop(context, "booking");
            },
          );
        }
        if (_isOwner) {
          editItem = AppListTitle(
            title: Translate.of(context).translate("edit"),
            leading: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.pop(context, "edit");
            },
          );
          removeItem = AppListTitle(
            title: Translate.of(context).translate("remove"),
            leading: const Icon(Icons.delete_outline),
            onPressed: () {
              Navigator.pop(context, "remove");
            },
          );
        }
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: IntrinsicHeight(
              child: Container(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    Column(
                      children: [
                        bookingItem,
                        editItem,
                        removeItem,
                        AppListTitle(
                          title: Translate.of(context).translate("share"),
                          leading: const Icon(Icons.share_outlined),
                          onPressed: () {
                            Navigator.pop(context, "share");
                          },
                          border: false,
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    switch (result) {
      case "booking":
        Navigator.pushNamed(
          context,
          Routes.booking,
          arguments: item.id,
        );
        break;
      case "remove":
        _onRemove(item);
        break;
      case "share":
        _onShare(item);
        break;
      case "edit":
        _onEdit(item);
        break;
      default:
        break;
    }
  }

  ///On Remove
  void _onRemove(ProductModel item) async {
    await ListRepository.removeProduct(item.id);
    _onRefresh();
  }

  ///On Share
  void _onShare(ProductModel item) {
    Share.share(
      'Check out my item ${item.link}',
      subject: 'PassionUI',
    );
  }

  ///On Edit
  void _onEdit(ProductModel item) {
    Navigator.pushNamed(
      context,
      Routes.submit,
      arguments: item,
    );
  }

  ///On navigate product detail
  void _onProductDetail(ProductModel item) {
    Navigator.pushNamed(context, Routes.productDetail, arguments: item.id);
  }

  ///On navigate submit form
  void _onSubmit() {
    Navigator.pushNamed(context, Routes.submit);
  }

  ///Build Content
  Widget _buildContent({
    List<ProductModel>? listProduct,
    List<ProductModel>? listProductPending,
    List<CommentModel>? listComment,
    required bool loadingMore,
  }) {
    ///Loading List Product
    Widget content = SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: AppProductItem(type: ProductViewType.small),
          );
        },
        childCount: 15,
      ),
    );

    ///Loading List Review
    if (_indexTab == 2) {
      content = SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: AppCommentItem(),
            );
          },
          childCount: 15,
        ),
      );
    }

    ///Build List Product
    if (listProduct != null && _indexTab == 0) {
      List list = List.from(listProduct);

      ///Empty List
      content = SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.sentiment_satisfied),
                Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Text(
                    Translate.of(context).translate('list_is_empty'),
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (loadingMore) {
        list.add(null);
      }
      if (list.isNotEmpty) {
        content = SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = list[index];

              ///Listing
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppProductItem(
                  item: item,
                  type: ProductViewType.small,
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert_outlined),
                    onPressed: () {
                      _onSheetAction(item);
                    },
                  ),
                  onPressed: () {
                    _onProductDetail(item);
                  },
                ),
              );
            },
            childCount: list.length,
          ),
        );
      }
    }

    ///Build List Product Pending
    if (listProductPending != null && _indexTab == 1) {
      List list = List.from(listProductPending);

      ///Empty List
      content = SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.sentiment_satisfied),
                Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Text(
                    Translate.of(context).translate('list_is_empty'),
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (loadingMore) {
        list.add(null);
      }
      if (list.isNotEmpty) {
        content = SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = list[index];

              ///Listing
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppProductItem(
                  item: item,
                  type: ProductViewType.small,
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert_outlined),
                    onPressed: () {
                      _onSheetAction(item);
                    },
                  ),
                  onPressed: () {
                    _onProductDetail(item);
                  },
                ),
              );
            },
            childCount: list.length,
          ),
        );
      }
    }

    ///Build List Comment
    if (listComment != null && _indexTab == 2) {
      List list = List.from(listComment);

      ///Empty List
      content = SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.sentiment_satisfied),
                Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Text(
                    Translate.of(context).translate('list_is_empty'),
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (loadingMore) {
        list.add(null);
      }
      if (list.isNotEmpty) {
        content = SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = list[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppCommentItem(
                  item: item,
                  onPressUser: () {
                    _onProfile(item.user);
                  },
                  showPostName: true,
                ),
              );
            },
            childCount: list.length,
          ),
        );
      }
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> action = [];

    return BlocProvider(
      create: (context) => _profileCubit,
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, profile) {
          List<ProductModel>? listProduct;
          List<ProductModel>? listProductPending;
          List<CommentModel>? listComment;
          bool showFilter = (_indexTab == 0 || (_indexTab == 1 && _isOwner));
          List<Widget> tabs = [
            Tab(text: Translate.of(context).translate('listing')),
            Tab(text: Translate.of(context).translate('review')),
          ];
          bool loadingMore = false;
          if (profile is ProfileSuccess) {
            user = profile.user;
            listProduct = profile.listProduct;
            listProductPending = profile.listProductPending;
            listComment = profile.listComment;
            loadingMore = profile.loadingMore;
          }
          if (_isOwner) {
            action = [
              AppButton(
                Translate.of(context).translate('add'),
                onPressed: _onSubmit,
                type: ButtonType.text,
              ),
            ];
            tabs = [
              Tab(text: Translate.of(context).translate('listing')),
              Tab(text: Translate.of(context).translate('pending')),
              Tab(text: Translate.of(context).translate('review')),
            ];
          }
          return Scaffold(
            body: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: <Widget>[
                SliverAppBar(
                  centerTitle: true,
                  title: Text(
                    Translate.of(context).translate('profile'),
                  ),
                  actions: action,
                  pinned: true,
                ),
                SliverPersistentHeader(
                  delegate: ProfileHeader(
                    height: 100,
                    user: user,
                    showQR: _isOwner,
                    onQRCode: _onQRCode,
                  ),
                  floating: false,
                  pinned: false,
                ),
                SliverPersistentHeader(
                  delegate: ProfileTab(
                    height: 160,
                    showFilter: showFilter,
                    tabs: tabs,
                    tabController: _tabController,
                    onTap: _onTap,
                    textSearchController: _textSearchController,
                    onSearch: _onSearch,
                    onFilter: _onFilter,
                    onSort: _onSort,
                  ),
                  pinned: true,
                  floating: false,
                ),
                CupertinoSliverRefreshControl(
                  onRefresh: _onRefresh,
                ),
                SliverSafeArea(
                  top: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    sliver: _buildContent(
                      listProduct: listProduct,
                      listProductPending: listProductPending,
                      listComment: listComment,
                      loadingMore: loadingMore,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
