import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class VideoTutorScreen extends StatefulWidget {
  const VideoTutorScreen({super.key});

  @override
  State<VideoTutorScreen> createState() => _VideoTutorScreenState();
}

class _VideoTutorScreenState extends State<VideoTutorScreen> {
  CameraController? _cameraController;

  bool _cameraEnabled = true;
  bool _isInitializing = true;

  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _isInitializing = true;
        _cameraError = null;
      });

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('Aucune caméra détectée.');
      }

      final frontCamera = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      final selectedCamera = frontCamera.isNotEmpty
          ? frontCamera.first
          : cameras.first;

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cameraError = e.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameraEnabled) {
      final controller = _cameraController;

      setState(() {
        _cameraEnabled = false;
        _cameraController = null;
      });

      await controller?.dispose();
    } else {
      setState(() {
        _cameraEnabled = true;
      });

      await _initializeCamera();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D19),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: Stack(
                children: [
                  _buildAvatarArea(),

                  Positioned(
                    right: 16,
                    bottom: 20,
                    child: _buildCameraPreview(),
                  ),

                  Positioned(
                    left: 20,
                    bottom: 30,
                    child: _buildConversationStatus(),
                  ),
                ],
              ),
            ),

            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Video Tutor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Your personal AI conversation partner',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.circle, color: Colors.greenAccent, size: 9),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarArea() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF182D50), Color(0xFF101A30), Color(0xFF080D19)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: const Icon(
              Icons.face_3_rounded,
              size: 85,
              color: Color(0xFFB8CCF5),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Your AI Avatar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Your realistic digital companion',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              '3D avatar integration coming next',
              style: TextStyle(color: Color(0xFFB8CCF5), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Container(
      width: 115,
      height: 155,
      decoration: BoxDecoration(
        color: const Color(0xFF202B40),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white38, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: !_cameraEnabled
          ? const Center(
              child: Icon(Icons.videocam_off, color: Colors.white70, size: 30),
            )
          : _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : _cameraError != null
          ? const Center(
              child: Icon(Icons.error_outline, color: Colors.white70, size: 30),
            )
          : _cameraController != null && _cameraController!.value.isInitialized
          ? CameraPreview(_cameraController!)
          : const Center(
              child: Icon(Icons.person, color: Colors.white70, size: 35),
            ),
    );
  }

  Widget _buildConversationStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.graphic_eq, color: Color(0xFF82A9FF), size: 18),
          SizedBox(width: 8),
          Text(
            'Ready to talk',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlButton(
            icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            onPressed: _toggleCamera,
          ),

          _controlButton(
            icon: Icons.mic_none,
            label: 'Microphone',
            onPressed: null,
          ),

          _controlButton(
            icon: Icons.call_end,
            label: 'End',
            color: Colors.redAccent,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color color = const Color(0xFF26354F),
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white12,
            disabledForegroundColor: Colors.white38,
            fixedSize: const Size(55, 55),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
