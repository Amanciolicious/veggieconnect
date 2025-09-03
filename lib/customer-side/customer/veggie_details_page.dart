// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'data/veggies_data.dart';

class VeggieDetailsPage extends StatefulWidget {
  final Map<String, dynamic> veggie;
  const VeggieDetailsPage({super.key, required this.veggie});

  @override
  State<VeggieDetailsPage> createState() => _VeggieDetailsPageState();
}

class _VeggieDetailsPageState extends State<VeggieDetailsPage> {
  int _qty = 1;
  bool _readMore = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardRadius = BorderRadius.circular(screenWidth * 0.05);
    final veggie = widget.veggie;
    final desc = veggie['desc'] as String;
    final showReadMore = desc.length > 90;
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: screenWidth * 0.11, left: screenWidth * 0.04, right: screenWidth * 0.04),
                    padding: EdgeInsets.only(top: screenWidth * 0.16, bottom: screenWidth * 0.06),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: cardRadius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Text(veggie['image'], style: TextStyle(fontSize: screenWidth * 0.22))),
                        SizedBox(height: screenWidth * 0.03),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                veggie['name'],
                                style: TextStyle(
                                  fontSize: screenWidth * 0.065,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              SizedBox(height: screenWidth * 0.015),
                              Row(
                                children: [
                                  ...List.generate(5, (i) => Icon(Icons.star, color: i < veggie['rating'].round() ? Color(0xFF6CA04A) : Color(0xFF757575).withOpacity(0.2), size: screenWidth * 0.05)),
                                  SizedBox(width: screenWidth * 0.02),
                                  Text(veggie['rating'].toString(), style: TextStyle(fontSize: screenWidth * 0.04, color: Color(0xFF757575), fontFamily: 'Poppins')),
                                ],
                              ),
                              SizedBox(height: screenWidth * 0.02),
                              Row(
                                children: [
                                  Text('\u20b1${veggie['price']}/KG', style: TextStyle(fontSize: screenWidth * 0.055, fontWeight: FontWeight.bold, color: Color(0xFF6CA04A), fontFamily: 'Poppins')),
                                  const Spacer(),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Color(0xFF6CA04A).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.remove, size: screenWidth * 0.05),
                                          onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                                        ),
                                        Text('$_qty KG', style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                                        IconButton(
                                          icon: Icon(Icons.add, size: screenWidth * 0.05),
                                          onPressed: () => setState(() => _qty++),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: screenWidth * 0.045),
                              Text('Product Details', style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                              SizedBox(height: screenWidth * 0.015),
                              Text(
                                showReadMore && !_readMore ? '${desc.substring(0, 90)}...' : desc,
                                style: TextStyle(fontSize: screenWidth * 0.04, color: Color(0xFF757575), fontFamily: 'Poppins', height: 1.5),
                              ),
                              if (showReadMore && !_readMore)
                                TextButton(
                                  onPressed: () => setState(() => _readMore = true),
                                  child: Text('Read More', style: TextStyle(color: Color(0xFF6CA04A), fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: screenWidth * 0.15,
                    left: screenWidth * 0.08,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: screenWidth * 0.06,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.black87, size: screenWidth * 0.06),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  Positioned(
                    top: screenWidth * 0.15,
                    right: screenWidth * 0.08,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: screenWidth * 0.06,
                      child: IconButton(
                        icon: Icon(Icons.favorite_border, color: Color(0xFF6CA04A), size: screenWidth * 0.06),
                        onPressed: () {},
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenWidth * 0.06),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                child: Text('Related Products', style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
              ),
              SizedBox(height: screenWidth * 0.02),
              SizedBox(
                height: screenWidth * 0.32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                  children: [
                    for (var v in veggies.where((v) => v['name'] != veggie['name']).take(4))
                      GestureDetector(
                        onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => VeggieDetailsPage(veggie: v)),
                        ),
                        child: Container(
                          margin: EdgeInsets.only(right: screenWidth * 0.03),
                          decoration: BoxDecoration(
                            color: Color(0xFF6CA04A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SizedBox(
                            width: screenWidth * 0.22,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(v['image'], style: TextStyle(fontSize: screenWidth * 0.08)),
                                SizedBox(height: screenWidth * 0.015),
                                Text(v['name'], style: TextStyle(fontSize: screenWidth * 0.04, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: screenWidth * 0.18),
            ],
          ),
          // Bottom bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06, vertical: screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Price', style: TextStyle(fontSize: screenWidth * 0.035, color: Color(0xFF757575), fontFamily: 'Poppins')),
                      Text('\u20b1${(veggie['price'] * _qty).toStringAsFixed(2)}', style: TextStyle(fontSize: screenWidth * 0.055, fontWeight: FontWeight.bold, color: Color(0xFF6CA04A), fontFamily: 'Poppins')),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6CA04A),
                      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {},
                    child: Text('Add to Cart', style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Poppins')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}