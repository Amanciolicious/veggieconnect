import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AppLoader extends StatelessWidget {
	final double? width;
	final double? height;
	final BoxFit fit;
	final Color? backgroundColor;

	const AppLoader({super.key, this.width, this.height, this.fit = BoxFit.contain, this.backgroundColor});

	@override
	Widget build(BuildContext context) {
		return Container(
			color: backgroundColor,
			alignment: Alignment.center,
			child: Lottie.asset(
				'assets/lottie-loading-json/Grocery shopping bag pickup and delivery.json',
				width: width,
				height: height,
				fit: fit,
				repeat: true,
			),
		);
	}
}


