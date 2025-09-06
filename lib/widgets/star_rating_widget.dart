import 'package:flutter/material.dart';

class StarRatingWidget extends StatefulWidget {
  final int rating;
  final Function(int) onRatingChanged;
  final bool isReadOnly;
  final double size;
  final Color activeColor;
  final Color inactiveColor;

  const StarRatingWidget({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.isReadOnly = false,
    this.size = 30.0,
    this.activeColor = Colors.amber,
    this.inactiveColor = Colors.grey,
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  int _currentRating = 0;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.rating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: widget.isReadOnly ? null : () {
            setState(() {
              _currentRating = index + 1;
            });
            widget.onRatingChanged(_currentRating);
          },
          child: Icon(
            index < _currentRating ? Icons.star : Icons.star_border,
            color: index < _currentRating ? widget.activeColor : widget.inactiveColor,
            size: widget.size,
          ),
        );
      }),
    );
  }
}

class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final bool showRatingText;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 20.0,
    this.activeColor = Colors.amber,
    this.inactiveColor = Colors.grey,
    this.showRatingText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          double starValue = rating - index;
          return Icon(
            starValue >= 1.0
                ? Icons.star
                : starValue >= 0.5
                    ? Icons.star_half
                    : Icons.star_border,
            color: starValue > 0 ? activeColor : inactiveColor,
            size: size,
          );
        }),
        if (showRatingText) ...[
          const SizedBox(width: 4),
          Text(
            '(${rating.toStringAsFixed(1)})',
            style: TextStyle(
              fontSize: size * 0.6,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ],
    );
  }
}
