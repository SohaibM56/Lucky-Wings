
import 'package:flutter/material.dart';

AppBar gameAppBar({required BuildContext context, required Widget title}) =>
    AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(color: const Color(0xff92e010)),
      ),
      backgroundColor: Colors.transparent,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: title,
      elevation: 0,
    );
