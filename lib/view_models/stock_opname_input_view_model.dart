import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/asset_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class StockOpnameInputViewModel extends ChangeNotifier {
  String errorMessage = '';
  bool isLoading = false;
  bool isFetchingMore = false;
  bool hasMore = true;
  int currentOffset = 0;
  final int limit = 20; // Sesuaikan dengan limit di backend
  int totalAssets = 0; // total semua data dari backend

  List<AssetData> assetList = [];

  // Fungsi untuk mengambil token dari SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchAssets(String selectedNoSO, {bool loadMore = false, List<String>? companyFilters, List<String>? categoryFilters, List<String>? locationFilters}) async {
    if (!loadMore) {
      // Reset state untuk load baru
      isLoading = true;
      currentOffset = 0;
      hasMore = true;
      assetList.clear();
    } else {
      // Set flag fetching more untuk load tambahan
      isFetchingMore = true;
    }

    errorMessage = '';
    notifyListeners();

    print("📡 Fetching assets for NoSO: $selectedNoSO, offset: $currentOffset");

    try {
      final uri = Uri.parse('${ApiConstants.listAssets(selectedNoSO)}').replace(
        queryParameters: {
          'offset': '$currentOffset',
          if (companyFilters != null && companyFilters.isNotEmpty)
            'company': companyFilters.join(','),
          if (categoryFilters != null && categoryFilters.isNotEmpty)
            'category': categoryFilters.join(','),
          if (locationFilters != null && locationFilters.isNotEmpty)
            'location': locationFilters.join(','),
        },
      );

      String? token = await _getToken();

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['data'];

        final newAssets = jsonData.map((json) => AssetData.fromJson(json)).toList();

        if (loadMore) {
          assetList.addAll(newAssets);
        } else {
          assetList = newAssets;
        }

        // ✅ Ambil total dari backend
        totalAssets = responseData['total'] ?? 0;

        // Update pagination state
        currentOffset = responseData['nextOffset'] ?? currentOffset + newAssets.length;
        hasMore = responseData['hasMore'] ?? (newAssets.length == limit);

        errorMessage = '';
        print("✅ Data berhasil dimuat: $totalAssets} assets");
      } else {
        totalAssets = 0;
        errorMessage = 'Gagal memuat data (${response.statusCode})';
      }
    } catch (e) {
      errorMessage = 'Terjadi kesalahan: $e';
    } finally {
      isLoading = false;
      isFetchingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreAssets(String selectedNoSO, {List<String>? companyFilters, List<String>? categoryFilters, List<String>? locationFilters}) async {
    if (!hasMore || isFetchingMore) return;
    await fetchAssets(selectedNoSO, loadMore: true, companyFilters: companyFilters, categoryFilters: categoryFilters, locationFilters: locationFilters);
  }
}