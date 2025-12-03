import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'lib/server.dart';

void main(List<String> args) async {
  final handler = Pipeline()
      .addMiddleware(corsHeaders())
      .addHandler(BlossomServer().router.call);  

  final port = int.fromEnvironment('PORT', defaultValue: 8080);
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print('Server running on ${server.address.host}:${server.port}');
}
