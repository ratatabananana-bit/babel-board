import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vale_helper/blocks/item_tile.dart';

import '../helpers.dart';

void main() {
  testWidgets('gallery tiles decode their picture at tile size, not full size', (tester) async {
    await pumpModules(tester);
    final img = tester.widget<Image>(
      find.descendant(of: find.byType(ItemTile), matching: find.byType(Image)).first,
    );
    expect(img.image, isA<ResizeImage>());
    final tileW = tester.getSize(find.byType(ItemTile).first).width;
    expect((img.image as ResizeImage).width, lessThanOrEqualTo((tileW * tester.view.devicePixelRatio).ceil()));
  });
}
