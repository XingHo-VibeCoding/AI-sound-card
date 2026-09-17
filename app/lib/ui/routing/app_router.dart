import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../screens/compare_screen.dart';
import '../screens/home_screen.dart';
import '../screens/practice_screen.dart';
import '../screens/recording_list_screen.dart';
import '../screens/review_pool_screen.dart';

/// 全局路由表。
///
/// 5 条路由：/home /practice /compare /recordings /review，
/// practice 与 compare 通过查询参数 `sentenceId` 传递句子 id。
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.home,
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.practice,
      builder: (BuildContext context, GoRouterState state) =>
          PracticeScreen(sentenceId: _intParam(state, 'sentenceId')),
    ),
    GoRoute(
      path: AppRoutes.compare,
      builder: (BuildContext context, GoRouterState state) =>
          CompareScreen(sentenceId: _intParam(state, 'sentenceId')),
    ),
    GoRoute(
      path: AppRoutes.recordings,
      builder: (BuildContext context, GoRouterState state) =>
          const RecordingListScreen(),
    ),
    GoRoute(
      path: AppRoutes.review,
      builder: (BuildContext context, GoRouterState state) =>
          const ReviewPoolScreen(),
    ),
  ],
);

int? _intParam(GoRouterState state, String name) {
  final String? value = state.uri.queryParameters[name];
  return value == null ? null : int.tryParse(value);
}
