import 'package:collection/collection.dart';
import 'package:domain/models/core_router.dart';
import 'package:domain/models/enums.dart';
import 'package:domain/models/page_route.dart';
import 'package:domain/models/transition_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:infrastructure/interfaces/iobserver.dart';
import 'package:infrastructure/interfaces/ipage_router_service.dart';

class PageRouterService implements IPageRouterService {
  List<PageRoutePoint> routes = [];

  @override
  late CoreRouter router;

  @override
  late int currentIndex = 0;

  @override
  late Object? callbackResult;

  @override
  late String lastPage;

  @override
  late String onSubmit;

  @override
  late String dashboard;

  @override
  late IObserver observer;

  late bool isLocked = true;
  late BuildContext lastContext;
  bool isBoxOpen = false;

  PageRouterService(IObserver current) {
    observer = current;
  }

  @override
  backToPrevious(BuildContext context, {bool reverse = false}) {
    if (isLocked) return;

    dismissBar(context);
    PageRoutePoint? point;
    if (routes.length > 1) {
      point = routes.elementAt(routes.length - 2);
      routes.removeLast();
    }

    if (point == null) return;

    SystemChannels.textInput.invokeMethod('TextInput.hide');
    context.go(
      point.route,
      extra: TransitionData(
        next: reverse ? PageTransition.slideForward : PageTransition.slideBack,
      ),
    );
  }

  @override
  backToPreviousFirst(BuildContext context, String route) {
    if (isLocked) return;

    SystemChannels.textInput.invokeMethod('TextInput.hide');

    dismissBar(context);
    List<PageRoutePoint> newRoutes = [];

    for (final element in routes) {
      if (element.route == route) {
        break;
      }
      newRoutes.add(element);
    }

    var page = newRoutes.last;
    routes = newRoutes;
    context.go(
      page.route,
      extra: TransitionData(
        next: PageTransition.slideBack,
      ),
    );
  }

  @override
  bool changePage(String name, BuildContext context, TransitionData data,
      {Object? bindingData,
      bool slice = false,
      int sliceCount = 1,
      bool saveRoute = true}) {
    if (isLocked) return false;

    SystemChannels.textInput.invokeMethod('TextInput.hide');

    //TODO have to figure a better way for disposing. This leads to bugs.
    //observer.disposeAll();
    if (saveRoute) routes.add(PageRoutePoint(route: name, data: bindingData));

    if (slice) {
      routes = routes.slice(0, routes.length - sliceCount).toList();
    }

    dismissBar(context);

    router.router.go(name, extra: data);
    return true;
  }

  @override
  void registerRouter(CoreRouter currentRouter) {
    router = currentRouter;
  }

  @override
  void setPageIndex(int index) {
    currentIndex = index;
  }

  @override
  void setCallbackResult(Object current) {
    callbackResult = current;
  }

  @override
  bool clearNavigationData() {
    routes.clear();
    return true;
  }

  @override
  Object? getPageBindingData() {
    return routes.elementAt(routes.length - 1).data;
  }

  @override
  openBar(Widget content, BuildContext context,
      {double? width, double? height}) async {
    lastContext = context;
    isBoxOpen = true;
    showModalBottomSheet(
        constraints: BoxConstraints(
          minWidth: width ?? 200,
          minHeight: height ?? 200,
        ),
        useSafeArea: true,
        useRootNavigator: true,
        elevation: 22,
        isScrollControlled: true,
        context: context,
        builder: (context) => SingleChildScrollView(
              child: Container(
                width: width,
                height: height,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: IntrinsicHeight(
                  child: content,
                ),
              ),
            ));
  }

  @override
  openDialog(Widget content, BuildContext context,
      {double? width, double? height}) {
    lastContext = context;
    isBoxOpen = true;

    showDialog(
      barrierDismissible: true,
      useSafeArea: true,
      useRootNavigator: true,
      context: context,
      builder: (context) => AlertDialog(
        content: FractionallySizedBox(
          heightFactor: 0.6,
          widthFactor: 1,
          child: content,
        ),
      ),
    );
  }

  @override
  dismissBar(BuildContext context) async {
    isBoxOpen = false;

    Navigator.pop(context);
  }
}
