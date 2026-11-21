import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

/// Message type enum
enum MessageType { text, image, file, system }

/// Image message model for Firebase Storage
class ImageMessage {
  final String imageId;
  final String downloadUrl;
  final String filePath;
  final String caption;
  final DateTime createdAt;

  ImageMessage({
    required this.imageId,
    required this.downloadUrl,
    required this.filePath,
    this.caption = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'imageId': imageId,
      'downloadUrl': downloadUrl,
      'filePath': filePath,
      'caption': caption,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ImageMessage.fromMap(Map<dynamic, dynamic> map, String imageId) {
    return ImageMessage(
      imageId: imageId,
      downloadUrl: map['downloadUrl']?.toString() ?? '',
      filePath: map['filePath']?.toString() ?? '',
      caption: map['caption']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now(),
    );
  }
}

/// Chat message model
class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String role; // 'CLIENT' or 'CAPTAIN'
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final String? readBy;
  final DateTime? readAt;
  final String? orderId;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.role,
    required this.content,
    required this.type,
    required this.createdAt,
    this.readBy,
    this.readAt,
    this.orderId,
  });

  factory ChatMessage.fromMap(Map<dynamic, dynamic> map, String id) {
    return ChatMessage(
      id: id,
      senderId: map['senderId']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',
      role: map['role']?.toString() ?? 'CLIENT',
      content: map['content']?.toString() ?? '',
      type: _stringToMessageType(map['type']?.toString() ?? 'text'),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now(),
      readBy: map['readBy']?.toString(),
      readAt: map['readAt'] != null ? DateTime.parse(map['readAt'].toString()) : null,
      orderId: map['orderId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'role': role,
      'content': content,
      'type': type.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'readBy': readBy,
      'readAt': readAt?.toIso8601String(),
      'orderId': orderId,
    };
  }

  static MessageType _stringToMessageType(String type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }
}

/// Firebase Chat Service using Realtime Database and Storage
class FirebaseChatService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Reference to messages collection for a specific order
  DatabaseReference _getOrderMessagesRef(String orderId) {
    return _db.ref('chat_messages/$orderId');
  }

  /// Reference to messages for a specific user
  DatabaseReference _getUserMessagesRef(String userId) {
    return _db.ref('user_messages/$userId');
  }

  /// Reference to image storage for a specific order
  Reference _getImageReference(String orderId, String imageId) {
    return _storage.ref().child('chat_images/$orderId/$imageId');
  }

  /// Send a new message
  Future<String> sendMessage({
    required String content,
    required String receiverId,
    required String role, // 'CLIENT' or 'CAPTAIN'
    required String orderId,
    MessageType type = MessageType.text,
    File? imageFile, // New parameter for images
  }) async {
    final senderId = _auth.currentUser?.uid ?? '';
    final messageId = _db.ref('chat_messages/$orderId').push().key ?? '';

    String finalContent = content;
    MessageType finalType = type;

    // Handle image upload if provided
    if (imageFile != null && type == MessageType.image) {
      final imageId = DateTime.now().millisecondsSinceEpoch.toString();
      final imageRef = _storage.ref().child('chat_images/$orderId/$imageId');
      await imageRef.putFile(imageFile);
      final downloadUrl = await imageRef.getDownloadURL();
      final imageMsg = ImageMessage(
        imageId: imageId,
        downloadUrl: downloadUrl,
        filePath: 'chat_images/$orderId/$imageId',
      );
      await _db
          .ref('chat_images/$orderId/$imageId')
          .set(imageMsg.toMap());
      finalContent = downloadUrl;
      finalType = MessageType.image;
    }

    final message = ChatMessage(
      id: messageId,
      senderId: senderId,
      receiverId: receiverId,
      role: role,
      content: finalContent,
      type: finalType,
      createdAt: DateTime.now(),
      orderId: orderId,
    );

    await _db.ref('chat_messages/$orderId/$messageId').set(message.toMap());

    // Also add to user_messages index for quick lookup
    await _db.ref('user_messages/$receiverId/$orderId/$messageId').set({
      'messageId': messageId,
      'senderId': senderId,
      'content': finalContent,
      'createdAt': DateTime.now().toIso8601String(),
      'orderId': orderId,
      'type': finalType.toString().split('.').last,
    });

    return messageId;
  }

  /// Listen to messages for a specific order (real-time stream)
  Stream<List<ChatMessage>> listenMessages(String orderId) {
    return _db.ref('chat_messages/$orderId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <ChatMessage>[];

      final Map<dynamic, dynamic> map = data as Map<dynamic, dynamic>;
      return map.entries.map((entry) {
        final value = entry.value as Map<dynamic, dynamic>;
        return ChatMessage.fromMap(value, entry.key.toString());
      }).toList(growable: false)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
  }

  /// Mark a message as read
  Future<void> markAsRead(String orderId, String messageId, String userId) async {
    await _db.ref('chat_messages/$orderId/$messageId/readBy').set(userId);
    await _db.ref('chat_messages/$orderId/$messageId/readAt').set(
      DateTime.now().toIso8601String(),
    );
  }

  /// Get current user's UID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  /// Get unread count for user across all orders
  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _db.ref('user_messages/$userId').get();
    if (!snapshot.exists) return 0;
    final Map<dynamic, dynamic>? data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return 0;
    int count = 0;
    data.forEach((orderId, messages) {
      if (messages is Map<dynamic, dynamic>) {
        messages.forEach((msgId, msg) {
          final msgMap = msg as Map<dynamic, dynamic>;
          if (msgMap['readBy'] == null || msgMap['readBy'] == '') {
            count++;
          }
        });
      }
    });
    return count;
  }
}