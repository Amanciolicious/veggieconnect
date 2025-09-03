// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'data/veggies_data.dart';
import 'veggie_details_page.dart';

class VeggiesPage extends StatelessWidget {
  const VeggiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Color(0xFFF8FAF5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6CA04A),
        title: Text(
          'Veggies',
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: screenWidth * 0.04,
          crossAxisSpacing: screenWidth * 0.04,
          childAspectRatio: 0.85,
          children: [
            for (var veggie in veggies)
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => VeggieDetailsPage(veggie: veggie)),
                ),
                child: _VeggieGridCard(veggie: veggie),
              ),
          ],
        ),
      ),
    );
  }
}

class _VeggieGridCard extends StatelessWidget {
  final Map<String, dynamic> veggie;
  const _VeggieGridCard({required this.veggie});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardRadius = BorderRadius.circular(screenWidth * 0.05);
    return Container(
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
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          children: [
            Text(veggie['image'], style: TextStyle(fontSize: screenWidth * 0.15)),
            SizedBox(height: screenWidth * 0.02),
            Text(
              veggie['name'],
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenWidth * 0.01),
            Text(
              '₱${veggie['price']}/kg',
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6CA04A),
                fontFamily: 'Poppins',
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => Icon(
                  Icons.star,
                  color: i < veggie['rating'].round() 
                      ? Color(0xFF6CA04A) 
                      : Color(0xFF757575).withOpacity(0.2),
                  size: screenWidth * 0.04,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}