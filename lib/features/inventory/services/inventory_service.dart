import 'package:flutter/foundation.dart';
import 'package:second_serving_frontend/core/config/api_config.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';

abstract class InventoryService {
  Future<InventoryListResponse> getItems({int skip = 0, int limit = 20});
  Future<List<InventoryItem>> getExpiringItems({int days = 3});
  Future<InventoryItem> createItem(Map<String, dynamic> data);
  Future<InventoryItem> updateItem(String id, Map<String, dynamic> data);
  Future<InventoryItem> consumeItem(String id);
  Future<InventoryItem> discardItem(String id, {required String reason, double? quantity});
  Future<void> deleteItem(String id);
}

class InventoryServiceImpl implements InventoryService {
  final ApiClient _client;

  InventoryServiceImpl(this._client);

  @override
  Future<InventoryListResponse> getItems({int skip = 0, int limit = 20}) async {
    final response = await _client.get(
      ApiConfig.inventory,
      queryParams: {'skip': '$skip', 'limit': '$limit'},
    );
    return InventoryListResponse.fromJson(response);
  }

  @override
  Future<List<InventoryItem>> getExpiringItems({int days = 3}) async {
    final response = await _client.get(
      ApiConfig.inventoryExpiring,
      queryParams: {'days': '$days'},
    );
    debugPrint('[InventoryService] getExpiringItems raw response: $response');
    final list = (response['items'] ?? response['data']) as List? ?? [];
    return list.map((e) => InventoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<InventoryItem> createItem(Map<String, dynamic> data) async {
    final response = await _client.post(ApiConfig.inventory, body: data);
    return InventoryItem.fromJson(response);
  }

  @override
  Future<InventoryItem> updateItem(String id, Map<String, dynamic> data) async {
    final response = await _client.put(ApiConfig.inventoryItem(id), body: data);
    return InventoryItem.fromJson(response);
  }

  @override
  Future<InventoryItem> consumeItem(String id) async {
    final response = await _client.patch(ApiConfig.consumeItem(id));
    return InventoryItem.fromJson(response);
  }

  @override
  Future<InventoryItem> discardItem(String id, {required String reason, double? quantity}) async {
    final response = await _client.patch(
      ApiConfig.discardItem(id),
      body: {
        'reason': reason,
        if (quantity != null) 'quantity': quantity,
      },
    );
    return InventoryItem.fromJson(response);
  }

  @override
  Future<void> deleteItem(String id) async {
    await _client.delete(ApiConfig.inventoryItem(id));
  }
}
