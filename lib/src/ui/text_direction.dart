import 'package:flutter/widgets.dart';

import '../l10n/strings.dart';

/// 文言の言語に合う文字の向き。アラビア語など右から左に書く言語は rtl。
TextDirection textDirectionOf(ChukoreStrings strings) =>
    strings.rightToLeft ? TextDirection.rtl : TextDirection.ltr;
