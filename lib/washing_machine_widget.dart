import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math' as math;

class Bubble {
  double x;
  double y;
  double size;
  double speed;
  double opacity;

  Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    this.opacity = 1.0,
  });
}

class WashingMachine extends StatefulWidget {
  const WashingMachine({super.key});

  @override
  State<WashingMachine> createState() => _WashingMachineState();
}

class _WashingMachineState extends State<WashingMachine>
    with TickerProviderStateMixin {
  late AnimationController _drumRotationController;
  late AnimationController _waterFillController;
  late AnimationController _clothesAnimationController;
  late AnimationController _waveController;
  late AnimationController _bubbleController;
  late AnimationController _clothesLoadController;

  late AudioPlayer _soundEffectPlayer;
  late AudioPlayer _washingLoopPlayer;

  bool _isPoweredOn = false;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isLoadingClothes = false;
  bool _isUnloadingClothes = false;
  bool _clothesInDrum = false;
  double _progress = 0.0;
  double _waterLevel = 0.0;
  String _currentCycle = 'Normal';
  String _status = 'Ready';
  double _dialRotation = 0.0;

  final List<Bubble> _bubbles = [];
  final math.Random _random = math.Random();

  final Map<String, int> _cycleDurations = {
    'Normal': 180,
    'Delicate': 120,
    'Heavy': 240,
  };

  final Map<String, double> _cycleSpeeds = {
    'Normal': 1.0,
    'Delicate': 0.6,
    'Heavy': 1.5,
  };

  @override
  void initState() {
    super.initState();

    _drumRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _waterFillController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _clothesAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(_updateBubbles);

    _clothesLoadController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        )..addListener(() {
          setState(() {});
        });

    _drumRotationController.addListener(() {
      if (_drumRotationController.isAnimating) {
        setState(() {});
      }
    });

    _waterFillController.addListener(() {
      if (_waterFillController.isAnimating) {
        setState(() {
          _waterLevel = _waterFillController.value;
        });
      }
    });

    _clothesAnimationController.addListener(() {
      if (_clothesAnimationController.isAnimating) {
        setState(() {});
      }
    });

    _soundEffectPlayer = AudioPlayer();
    _washingLoopPlayer = AudioPlayer();
    _washingLoopPlayer.setReleaseMode(ReleaseMode.loop);
    _washingLoopPlayer.setVolume(0.3);
  }

  void _updateBubbles() {
    if (!_isRunning || _isPaused) return;

    setState(() {
      if (_random.nextDouble() < 0.1 && _bubbles.length < 15) {
        _bubbles.add(
          Bubble(
            x: _random.nextDouble() * 160 + 10,
            y: 160,
            size: _random.nextDouble() * 6 + 2,
            speed: _random.nextDouble() * 2 + 1,
          ),
        );
      }

      for (int i = _bubbles.length - 1; i >= 0; i--) {
        _bubbles[i].y -= _bubbles[i].speed;
        _bubbles[i].x += (_random.nextDouble() - 0.5) * 2;
        _bubbles[i].opacity -= 0.01;

        if (_bubbles[i].y < 20 || _bubbles[i].opacity <= 0) {
          _bubbles.removeAt(i);
        }
      }
    });
  }

  @override
  void dispose() {
    _drumRotationController.dispose();
    _waterFillController.dispose();
    _clothesAnimationController.dispose();
    _waveController.dispose();
    _bubbleController.dispose();
    _clothesLoadController.dispose();
    _soundEffectPlayer.dispose();
    _washingLoopPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(String soundName) async {
    await _soundEffectPlayer.play(AssetSource('sounds/$soundName.wav'));
  }

  Future<void> _startWashingSound() async {
    await _washingLoopPlayer.play(AssetSource('sounds/washing.wav'));
  }

  Future<void> _stopWashingSound() async {
    await _washingLoopPlayer.stop();
  }

  void _togglePower() {
    setState(() {
      _isPoweredOn = !_isPoweredOn;
      if (!_isPoweredOn) {
        _stopWashing();
        _playSound('power_off');
      } else {
        _playSound('power_on');
      }
    });
  }

  void _startWashing() {
    if (!_isPoweredOn || _isLoadingClothes) return;

    if (!_clothesInDrum) {
      _loadClothes();
      return;
    }

    setState(() {
      _isRunning = true;
      _isPaused = false;
      _status = 'Washing...';
      _progress = 0.0;

      final speed = _cycleSpeeds[_currentCycle]!;
      _drumRotationController.duration = Duration(
        milliseconds: (2000 / speed).round(),
      );
      _drumRotationController.repeat();
      _clothesAnimationController.repeat();
      _waterFillController.forward();
      _bubbleController.repeat();

      _playSound('start');
      _startWashingSound();
      _startProgressTimer();
    });
  }

  void _loadClothes() {
    setState(() {
      _isLoadingClothes = true;
      _status = 'Loading...';
    });

    _clothesLoadController.forward().then((_) {
      setState(() {
        _isLoadingClothes = false;
        _clothesInDrum = true;
        _status = 'Ready';
        _playSound('button_press');
      });
    });
  }

  void _unloadClothes() {
    setState(() {
      _isUnloadingClothes = true;
      _status = 'Unloading...';
    });

    _clothesLoadController.reverse().then((_) {
      setState(() {
        _isUnloadingClothes = false;
        _clothesInDrum = false;
        _status = 'Ready';
        _playSound('button_press');
      });
    });
  }

  void _pauseWashing() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _drumRotationController.stop();
        _clothesAnimationController.stop();
        _bubbleController.stop();
        _washingLoopPlayer.pause();
        _status = 'Paused';
      } else {
        _drumRotationController.repeat();
        _clothesAnimationController.repeat();
        _bubbleController.repeat();
        _washingLoopPlayer.resume();
        _status = 'Washing...';
      }
    });
  }

  void _stopWashing() {
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _status = 'Ready';
      _progress = 0.0;
      _waterLevel = 0.0;
      _bubbles.clear();

      _drumRotationController.stop();
      _clothesAnimationController.stop();
      _bubbleController.stop();
      _waterFillController.reverse();
      _stopWashingSound();
    });
  }

  void _resetMachine() {
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _status = 'Ready';
      _progress = 0.0;
      _waterLevel = 0.0;
      _bubbles.clear();
      _clothesInDrum = false;
      _isLoadingClothes = false;
      _isUnloadingClothes = false;

      _drumRotationController.stop();
      _clothesAnimationController.stop();
      _bubbleController.stop();
      _clothesLoadController.reset();
      _waterFillController.reset();
      _stopWashingSound();
    });
  }

  String _formatTimeRemaining() {
    if (!_isRunning) return '--:--';

    final remainingSeconds =
        ((_cycleDurations[_currentCycle]! * (1 - _progress)).round());
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _selectCycle(String cycle) {
    setState(() {
      _currentCycle = cycle;
      _dialRotation = _getDialRotationForCycle(cycle);
      _stopWashing();
      _playSound('button_press');
    });
  }

  double _getDialRotationForCycle(String cycle) {
    switch (cycle) {
      case 'Normal':
        return 0;
      case 'Delicate':
        return 120;
      case 'Heavy':
        return 240;
      default:
        return 0;
    }
  }

  void _startProgressTimer() {
    const duration = Duration(seconds: 1);
    Timer.periodic(duration, (timer) {
      if (!_isRunning || _isPaused) {
        timer.cancel();
        return;
      }

      setState(() {
        _progress += 1.0 / _cycleDurations[_currentCycle]!;
        if (_progress >= 1.0) {
          _isRunning = false;
          _progress = 1.0;
          _status = 'Complete';
          _drumRotationController.stop();
          _clothesAnimationController.stop();
          _bubbleController.stop();
          _stopWashingSound();
          _playSound('complete');
          timer.cancel();

          Future.delayed(const Duration(milliseconds: 1500), () {
            _waterFillController.reverse();
            Future.delayed(const Duration(milliseconds: 2500), () {
              _unloadClothes();
            });
          });
        }
      });
    });
  }

  List<Widget> _buildTumblingClothes() {
    return [
      Positioned(
        top: 50 + (_clothesAnimationController.value * 30).toDouble(),
        left: 50 + (_clothesAnimationController.value * 20).toDouble(),
        child: Transform.rotate(
          angle: _drumRotationController.value * 2 * 3.14159,
          child: Icon(
            Icons.checkroom,
            color: Colors.white.withOpacity(0.9),
            size: 30,
          ),
        ),
      ),
      Positioned(
        top: 80 - (_clothesAnimationController.value * 20).toDouble(),
        right: 40 + (_clothesAnimationController.value * 15).toDouble(),
        child: Transform.rotate(
          angle: -_drumRotationController.value * 2 * 3.14159,
          child: Icon(
            Icons.checkroom,
            color: Colors.white.withOpacity(0.9),
            size: 25,
          ),
        ),
      ),
      Positioned(
        top: 60 + (_clothesAnimationController.value * 15).toDouble(),
        left: 30 - (_clothesAnimationController.value * 10).toDouble(),
        child: Transform.rotate(
          angle: _drumRotationController.value * 2 * 3.14159 + 0.5,
          child: Icon(
            Icons.checkroom,
            color: Colors.white.withOpacity(0.85),
            size: 22,
          ),
        ),
      ),
    ];
  }

  Widget _buildClothesPile() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: -0.2,
            child: Icon(
              Icons.checkroom,
              color: Colors.blue[400],
              size: 32,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 3,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(8, -8),
            child: Transform.rotate(
              angle: 0.3,
              child: Icon(
                Icons.checkroom,
                color: Colors.indigo[300],
                size: 28,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 3,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(-5, -15),
            child: Transform.rotate(
              angle: -0.1,
              child: Icon(
                Icons.checkroom,
                color: Colors.teal[300],
                size: 26,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 3,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miele Washing Machine'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Miele Washing Machine Body
              Container(
                width: 380,
                height: 520,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: MieleBodyPainter(),
                  child: Column(
                    children: [
                      // Control Panel with Miele styling
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Miele Logo
                            Positioned(
                              left: 20,
                              top: 25,
                              child: Text(
                                'MIELE',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                  letterSpacing: 2,
                                ),
                              ),
                            ),

                            // Digital Display
                            Positioned(
                              right: 20,
                              top: 15,
                              child: Container(
                                width: 120,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey[700]!,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _formatTimeRemaining(),
                                    style: TextStyle(
                                      color: Colors.green[400],
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Control buttons
                            Positioned(
                              right: 20,
                              bottom: 15,
                              child: Row(
                                children: [
                                  // Power button
                                  GestureDetector(
                                    onTap: _togglePower,
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: _isPoweredOn
                                            ? Colors.grey[100]
                                            : Colors.grey[300],
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey[400]!,
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _isPoweredOn
                                            ? Icons.power
                                            : Icons.power_off,
                                        color: _isPoweredOn
                                            ? Colors.black
                                            : Colors.grey[600],
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  // Start/Pause button
                                  GestureDetector(
                                    onTap:
                                        _isLoadingClothes || _isUnloadingClothes
                                        ? null
                                        : _isRunning
                                        ? _pauseWashing
                                        : _startWashing,
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color:
                                            _isLoadingClothes ||
                                                _isUnloadingClothes
                                            ? Colors.grey[300]
                                            : _isRunning
                                            ? Colors.orange[500]
                                            : _clothesInDrum
                                            ? Colors.green[500]
                                            : Colors.grey[100],
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey[400]!,
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _isLoadingClothes
                                            ? Icons.downloading
                                            : _isUnloadingClothes
                                            ? Icons.upload
                                            : _isRunning
                                            ? Icons.pause
                                            : _clothesInDrum
                                            ? Icons.play_arrow
                                            : Icons.add_circle_outline,
                                        color:
                                            _isLoadingClothes ||
                                                _isUnloadingClothes
                                            ? Colors.grey[600]
                                            : _isRunning
                                            ? Colors.white
                                            : _clothesInDrum
                                            ? Colors.white
                                            : Colors.black,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Circular Dial Selector
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Dial background
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey[400]!,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _currentCycle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ),
                            // Dial indicator
                            Transform.rotate(
                              angle: _dialRotation * math.pi / 180,
                              child: Container(
                                width: 4,
                                height: 50,
                                margin: const EdgeInsets.only(top: 60),
                                decoration: BoxDecoration(
                                  color: Colors.red[500],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Large Circular Porthole Door
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Door frame with chrome effect
                            Container(
                              margin: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(120),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 15,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(105),
                                child: Stack(
                                  children: [
                                    // Chrome ring effect
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.grey[300]!,
                                            Colors.grey[400]!,
                                            Colors.white,
                                            Colors.grey[400]!,
                                            Colors.grey[300]!,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          105,
                                        ),
                                      ),
                                    ),
                                    // Glass effect
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          105,
                                        ),
                                        border: Border.all(
                                          color: Colors.grey[200]!,
                                          width: 3,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          105,
                                        ),
                                        child: Stack(
                                          children: [
                                            if (_waterLevel > 0)
                                              Positioned.fill(
                                                child: CustomPaint(
                                                  painter: WaterWavePainter(
                                                    waveValue:
                                                        _waveController.value,
                                                    waterLevel: _waterLevel,
                                                    isRunning:
                                                        _isRunning &&
                                                        !_isPaused,
                                                  ),
                                                ),
                                              ),
                                            if (_isRunning &&
                                                _bubbles.isNotEmpty)
                                              ..._bubbles.map(
                                                (bubble) => Positioned(
                                                  left: bubble.x,
                                                  top: bubble.y,
                                                  child: Container(
                                                    width: bubble.size,
                                                    height: bubble.size,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(
                                                            bubble.opacity *
                                                                0.6,
                                                          ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Transform.rotate(
                                              angle:
                                                  _drumRotationController
                                                      .value *
                                                  2 *
                                                  3.14159,
                                              child: Container(
                                                width: 220,
                                                height: 220,
                                                decoration: BoxDecoration(
                                                  color: Colors.transparent,
                                                  border: Border.all(
                                                    color: Colors.grey[300]!,
                                                    width: 4,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        110,
                                                      ),
                                                ),
                                                child: Center(
                                                  child: Container(
                                                    width: 200,
                                                    height: 200,
                                                    decoration: BoxDecoration(
                                                      color: Colors.transparent,
                                                      border: Border.all(
                                                        color:
                                                            Colors.grey[200]!,
                                                        width: 3,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            100,
                                                          ),
                                                    ),
                                                    child: Stack(
                                                      children: [
                                                        if (_isRunning &&
                                                            _clothesInDrum)
                                                          ..._buildTumblingClothes(),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_clothesInDrum && !_isRunning)
                                              Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.checkroom,
                                                      color: Colors.blue[400]!
                                                          .withOpacity(0.8),
                                                      size: 40,
                                                    ),
                                                    Icon(
                                                      Icons.checkroom,
                                                      color: Colors.blue[300]!
                                                          .withOpacity(0.6),
                                                      size: 32,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (_isLoadingClothes || _isUnloadingClothes)
                              Positioned(
                                left: _isLoadingClothes
                                    ? -100 +
                                          (_clothesLoadController.value * 150)
                                    : 50 - (_clothesLoadController.value * 150),
                                top:
                                    100 +
                                    math.sin(
                                          _clothesLoadController.value *
                                              math.pi,
                                        ) *
                                        -30,
                                child: _buildClothesPile(),
                              ),

                            if (!_clothesInDrum &&
                                !_isLoadingClothes &&
                                !_isUnloadingClothes)
                              Positioned(
                                left: -100,
                                top: 100,
                                child: _buildClothesPile(),
                              ),

                            if (_isUnloadingClothes &&
                                _clothesLoadController.value < 0.5)
                              Positioned(
                                right: -100,
                                top:
                                    100 +
                                    (1 - _clothesLoadController.value * 2) * 70,
                                child: Opacity(
                                  opacity: _clothesLoadController.value * 2,
                                  child: Transform.rotate(
                                    angle: _clothesLoadController.value * 0.3,
                                    child: _buildClothesPile(),
                                  ),
                                ),
                              ),

                            Positioned(
                              right: 20,
                              top: 100,
                              child: Container(
                                width: 40,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Progress Bar
                      if (_isPoweredOn)
                        Container(
                          margin: const EdgeInsets.all(20),
                          width: 320,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: _progress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green[400]!,
                                    Colors.green[500]!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Status Text
              if (_isPoweredOn)
                Text(
                  'Cycle: $_currentCycle | Progress: ${(_progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MieleBodyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Main body - white with subtle gradient
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white.withOpacity(0.95)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bodyPaint);

    // Silver/brushed aluminum accents - top and bottom borders
    final accentPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.grey[300]!, Colors.grey[400]!, Colors.grey[300]!],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Top accent
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 15), accentPaint);
    // Bottom accent
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 15, size.width, 15),
      accentPaint,
    );

    // Silver trim around edges
    final trimPaint = Paint()
      ..color = Colors.grey[350]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), trimPaint);
  }

  @override
  bool shouldRepaint(covariant MieleBodyPainter oldDelegate) {
    return false;
  }
}

class WaterWavePainter extends CustomPainter {
  final double waveValue;
  final double waterLevel;
  final bool isRunning;

  WaterWavePainter({
    required this.waveValue,
    required this.waterLevel,
    required this.isRunning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final waterHeight = size.height * (1 - waterLevel * 0.7);
    final waveAmplitude = isRunning ? 8.0 : 3.0;
    final waveFrequency = isRunning ? 3.0 : 1.5;

    final paint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.lightBlue[300]!.withOpacity(0.7),
              Colors.blue[400]!.withOpacity(0.8),
              Colors.blue[600]!.withOpacity(0.9),
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              waterHeight,
              size.width,
              size.height - waterHeight,
            ),
          );

    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y =
          waterHeight +
          math.sin(
                (x / size.width * 2 * math.pi * waveFrequency) +
                    (waveValue * 2 * math.pi),
              ) *
              waveAmplitude +
          math.sin(
                (x / size.width * 2 * math.pi * waveFrequency * 1.5) +
                    (waveValue * 4 * math.pi),
              ) *
              (waveAmplitude * 0.5);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final highlightPath = Path();
    for (double x = 0; x <= size.width; x++) {
      final y =
          waterHeight +
          math.sin(
                (x / size.width * 2 * math.pi * waveFrequency) +
                    (waveValue * 2 * math.pi),
              ) *
              waveAmplitude +
          math.sin(
                (x / size.width * 2 * math.pi * waveFrequency * 1.5) +
                    (waveValue * 4 * math.pi),
              ) *
              (waveAmplitude * 0.5);
      if (x == 0) {
        highlightPath.moveTo(x, y);
      } else {
        highlightPath.lineTo(x, y);
      }
    }

    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant WaterWavePainter oldDelegate) {
    return oldDelegate.waveValue != waveValue ||
        oldDelegate.waterLevel != waterLevel ||
        oldDelegate.isRunning != isRunning;
  }
}
