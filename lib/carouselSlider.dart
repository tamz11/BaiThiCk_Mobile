import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:baithick/model/bannerModel.dart';
import 'package:baithick/screens/disease.dart';
import 'package:baithick/screens/diseasedetail.dart';
import 'package:baithick/screens/branch_map_screen.dart';

class Carouselslider extends StatelessWidget {
  const Carouselslider({super.key});

  Widget _buildBannerArtwork(int index) {
    if (index != 2) {
      return Image.asset(bannerCards[index].image, fit: BoxFit.fitHeight);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 18),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
            const Icon(Icons.map_rounded, size: 54, color: Color(0xFF2B7A78)),
            const Positioned(
              top: 16,
              right: 4,
              child: Icon(
                Icons.location_on_rounded,
                size: 24,
                color: Color(0xFF1F5A78),
              ),
            ),
            const Positioned(
              bottom: 14,
              left: 4,
              child: Icon(
                Icons.local_hospital_rounded,
                size: 20,
                color: Color(0xFF2F6B4F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: MediaQuery.of(context).size.width,
      child: CarouselSlider.builder(
        itemCount: bannerCards.length,
        itemBuilder: (context, index, realIndex) {
          return Container(
            height: 140,
            margin: EdgeInsets.only(left: 0, right: 0, bottom: 20),
            padding: EdgeInsets.only(left: 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                stops: [0.3, 0.7],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: bannerCards[index].cardBackground,
              ),
            ),
            child: GestureDetector(
              onTap: () {
                if (index == 0) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (BuildContext context) {
                        return Disease();
                      },
                    ),
                  );
                  return;
                }

                if (index == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (BuildContext context) {
                        return DiseaseDetail(disease: 'Covid-19');
                      },
                    ),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return const BranchMapScreen();
                    },
                  ),
                );
              },
              child: Stack(
                children: [
                  _buildBannerArtwork(index),
                  Container(
                    padding: EdgeInsets.only(top: 7, right: 5),
                    alignment: Alignment.topRight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          bannerCards[index].text,
                          style: GoogleFonts.lato(
                            color: Colors.lightBlue[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.lightBlue[900],
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        options: CarouselOptions(
          autoPlay: true,
          enlargeCenterPage: true,
          enableInfiniteScroll: false,
          scrollPhysics: ClampingScrollPhysics(),
        ),
      ),
    );
  }
}
