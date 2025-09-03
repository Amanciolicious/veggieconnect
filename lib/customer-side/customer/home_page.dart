// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'data/veggies_data.dart';
import 'veggies_page.dart';
import 'veggie_details_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final green = const Color(0xFFA7C957);
    final darkGreen = const Color(0xFF6CA04A);
    final cardRadius = BorderRadius.circular(screenWidth * 0.05);
    final neumorphicShadow = [
      BoxShadow(
        color: Colors.grey.shade300,
        offset: Offset(screenWidth * 0.015, screenWidth * 0.015),
        blurRadius: screenWidth * 0.04,
      ),
      BoxShadow(
        color: Colors.white,
        offset: Offset(-screenWidth * 0.015, -screenWidth * 0.015),
        blurRadius: screenWidth * 0.04,
      ),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: green,
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenWidth * 0.045),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white, size: screenWidth * 0.05),
                      SizedBox(width: screenWidth * 0.02),
                      Text('Your Location', style: TextStyle(color: Colors.white70, fontSize: screenWidth * 0.035)),
                      const Spacer(),
                      Icon(Icons.notifications_none, color: Colors.white, size: screenWidth * 0.05),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Text('Welcome, Vegie Lover!', style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold)),
                  SizedBox(height: screenWidth * 0.04),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: cardRadius,
                      boxShadow: neumorphicShadow,
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: screenWidth * 0.03),
                        Icon(Icons.search, color: Colors.black38, size: screenWidth * 0.05),
                        SizedBox(width: screenWidth * 0.02),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search Vegetables',
                              border: InputBorder.none,
                            ),
                            style: TextStyle(fontSize: screenWidth * 0.04),
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.03),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenWidth * 0.045),
              padding: EdgeInsets.all(screenWidth * 0.045),
              decoration: BoxDecoration(
                color: green.withOpacity(0.15),
                borderRadius: cardRadius,
                boxShadow: neumorphicShadow,
              ),
              child: Row(
                children: [
                  Icon(Icons.local_offer, color: green, size: screenWidth * 0.09),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Get 40% discount on your first order from app.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenWidth * 0.04)),
                        SizedBox(height: screenWidth * 0.015),
                        Text('Shop Now', style: TextStyle(color: green, fontWeight: FontWeight.w500, fontSize: screenWidth * 0.035)),
                      ],
                    ),
                  ),
                  Icon(Icons.eco, color: darkGreen, size: screenWidth * 0.11),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Text('Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenWidth * 0.045)),
            ),
            SizedBox(height: screenWidth * 0.03),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VeggiesPage())),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: green.withOpacity(0.15),
                            radius: screenWidth * 0.08,
                            child: Icon(Icons.eco, color: green, size: screenWidth * 0.08),
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          Text('Veggies', style: TextStyle(fontWeight: FontWeight.w500, fontSize: screenWidth * 0.04)),
                        ],
                      ),
                    ),
                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ),
            SizedBox(height: screenWidth * 0.06),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Text('Popular', style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenWidth * 0.045)),
            ),
            SizedBox(height: screenWidth * 0.03),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: screenWidth * 0.04,
                crossAxisSpacing: screenWidth * 0.04,
                childAspectRatio: 1.1,
                children: [
                  for (var veggie in veggies.take(4))
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => VeggieDetailsPage(veggie: veggie)),
                      ),
                      child: _VeggieCard(veggie: veggie),
                    ),
                ],
              ),
            ),
            SizedBox(height: screenWidth * 0.08),
          ],
        ),
      ),
    );
  }
}

class _VeggieCard extends StatelessWidget {
  final Map<String, dynamic> veggie;
  const _VeggieCard({required this.veggie});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final green = const Color(0xFFA7C957);
    final cardRadius = BorderRadius.circular(screenWidth * 0.05);
    final neumorphicShadow = [
      BoxShadow(
        color: Colors.grey.shade300,
        offset: Offset(screenWidth * 0.015, screenWidth * 0.015),
        blurRadius: screenWidth * 0.04,
      ),
      BoxShadow(
        color: Colors.white,
        offset: Offset(-screenWidth * 0.015, -screenWidth * 0.015),
        blurRadius: screenWidth * 0.04,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: green.withOpacity(0.10),
        borderRadius: cardRadius,
        boxShadow: neumorphicShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(veggie['image'], style: TextStyle(fontSize: screenWidth * 0.09)),
          SizedBox(height: screenWidth * 0.025),
          Text(veggie['name'], style: TextStyle(fontWeight: FontWeight.w600, fontSize: screenWidth * 0.04)),
          SizedBox(height: screenWidth * 0.015),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: Colors.orange, size: screenWidth * 0.04),
              Text('${veggie['rating']}', style: TextStyle(fontSize: screenWidth * 0.035)),
            ],
          ),
        ],
      ),
    );
  }
} 