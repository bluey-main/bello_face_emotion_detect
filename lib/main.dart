import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get_ip_address/get_ip_address.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:image/image.dart' as img;

enum DetectionStatus { noFace, fail, success }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Recognition Application',
      theme: ThemeData(useMaterial3: true),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  late WebSocketChannel channel;
  bool _faceDetected = true; // Initially assuming face is detected
  String? _label;
  String? _ipAddress;

  @override
  void initState() {
    super.initState();
    initializeCamera();
    initializeWebSocket();
    getIpAddress();
  }

Future<void> getIpAddress() async{
  try {
    /// Initialize Ip Address
    var ipAddress = IpAddress(type: RequestType.json);

    /// Get the IpAddress based on requestType.
    dynamic data = await ipAddress.getIpAddress();
    _ipAddress = data.toString();
    print(data.toString());
  } on IpAddressException catch (exception) {
    /// Handle the exception.
    print(exception.message);
  }
}


  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras[1]; // back 0th index & front 1st index

    controller = CameraController(
      firstCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller!.initialize();
    setState(() {});

    Timer.periodic(const Duration(milliseconds: 1), (timer) async {
      try {
        final image = await controller!.takePicture();
        final compressedImageBytes = compressImage(image.path);
        channel.sink.add(compressedImageBytes);
      } catch (_) {}
    });
  }

  void initializeWebSocket() {
    // 0.0.0.0 -> 10.0.2.2 (emulator)
    channel = IOWebSocketChannel.connect('ws://192.168.43.231:5555');
    channel.stream.listen((dynamic data) {
      debugPrint(data);
      data = jsonDecode(data);
      if (data['message'] == null) {
        debugPrint('Server error occurred in recognizing face');
        return;
      }

      bool status = data['status'];
      String? label = data['message'];

      setState(() {
        _faceDetected = status;
        _label = label;
      });
    }, onError: (dynamic error) {
      debugPrint('Error: $error');
    }, onDone: () {
      debugPrint('WebSocket connection closed');
    });
  }

  Uint8List compressImage(String imagePath, {int quality = 85}) {
    final image =
        img.decodeImage(Uint8List.fromList(File(imagePath).readAsBytesSync()))!;
    final compressedImage =
        img.encodeJpg(image, quality: quality); // lossless compression
    return compressedImage;
  }

  @override
  void dispose() {
    controller?.dispose();
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(controller?.value.isInitialized ?? false)) {
      return const SizedBox();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
      ),
      body: Center(
        child: Text('') ,
      ));

    // return CameraViewDetector(controller: controller, label: _label);
    // return Stack(
    //   children: [
    //     Positioned.fill(
    //       child: Container(
    //         width: 200,
    //         height: 200,
    //         child: AspectRatio(
    //           aspectRatio: controller!.value.aspectRatio,
    //           child: CameraPreview(controller!),
    //         ),
    //       ),
    //     ),
    //     Align(
    //       alignment: const Alignment(0, .85),
    //       child: ElevatedButton(
    //         // style:
    //         //     ElevatedButton.styleFrom(surfaceTintColor: currentStatusColor),
    //         child: Text(
    //           'Label: $_label',
    //           style: const TextStyle(
    //             color: Colors.green,
    //           ),
    //           //
    //           // style: const TextStyle(fontSize: 20),
    //         ),
    //         onPressed: () {},
    //       ),
    //     )
    //   ],
    // );
  }
}

class CameraViewDetector extends StatelessWidget {
  const CameraViewDetector({
    super.key,
    required this.controller,
    required String? label,
  }) : _label = label;

  final CameraController? controller;
  final String? _label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Stack(
            children: [
              Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  width: 300,
                  height: 500,
                  child: CameraPreview(controller!),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18.0),
                  child: Text(
                    'Label: $_label',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 40,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: EdgeInsets.all(20)),
                onPressed: () async {
                  // await controller.switchToFrontCamera();
                },
                child: Icon(
                  Icons.camera_front,
                  size: 50,
                  color: Colors.green,
                ),
              ),
              SizedBox(
                width: 40,
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: EdgeInsets.all(20)),
                onPressed: () {},
                child: Icon(
                  Icons.camera_rear,
                  size: 50,
                  color: Colors.orange,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
