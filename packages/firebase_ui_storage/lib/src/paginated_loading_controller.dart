// Copyright 2023, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// A base class for loading states.
sealed class PaginatedLoadingState {
  const PaginatedLoadingState();
}

/// Indicates that the first page is loading.
class InitialPageLoading extends PaginatedLoadingState {
  const InitialPageLoading();
}

class PageLoading extends PaginatedLoadingState {
  final List<Reference> items;

  const PageLoading({required this.items});
}

class PageLoadComplete extends PaginatedLoadingState {
  final List<Reference> pageItems;
  final List<Reference> items;

  const PageLoadComplete({
    required this.pageItems,
    required this.items,
  });
}

class PageLoadError extends PaginatedLoadingState {
  final Object? error;
  final List<Reference>? items;

  const PageLoadError({
    required this.error,
    this.items,
  });
}

class PaginatedLoadingController extends ChangeNotifier {
  int pageSize;
  final Reference ref;

  PaginatedLoadingController({
    required this.ref,
    this.pageSize = 50,
  }) {
    load();
  }

  PaginatedLoadingState? _state;
  PaginatedLoadingState get state => _state!;

  ListResult? _cursor;
  List<Reference>? _items;

  ListOptions get _listOptions {
    return ListOptions(
      maxResults: pageSize,
      pageToken: _cursor?.nextPageToken,
    );
  }

  Future<void> load() {
    _state = _state == null
        ? const InitialPageLoading()
        : PageLoading(items: _items!);

    final completer = Completer();

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      notifyListeners();

      try {
        final value = await ref.list(_listOptions);

        _cursor = value;
        (_items ??= []).addAll(value.items);

        _state = PageLoadComplete(
          pageItems: value.items,
          items: _items!,
        );
      } catch (err) {
        _state = PageLoadError(
          error: err,
          items: _items,
        );
      } finally {
        completer.complete();
        notifyListeners();
      }
    });

    return completer.future;
  }

  bool shouldLoadNextPage(int itemIndex) {
    return switch (state) {
      InitialPageLoading() => false,
      PageLoading() => false,
      PageLoadComplete(items: final items) =>
        itemIndex == (items.length - pageSize + 1),
      PageLoadError() => false,
    };
  }
}
