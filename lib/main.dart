// ignore_for_file: prefer_final_fields, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(SpaceShooterApp());
}

class SpaceShooterApp extends StatelessWidget {
  const SpaceShooterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Space Shooter',
      theme: ThemeData.dark(),
      home: GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late AnimationController _gameController;
  late AnimationController _explosionController;
  late Timer _gameTimer;
  late Timer _alienSpawnTimer;
  late FocusNode _focusNode;

  // Game state
  bool _gameStarted = false;
  bool _gameOver = false;
  int _score = 0;
  double _gameSpeed = 0.7; // Set to 0.7
  int _level = 1;

  // Player
  double _playerX = 0.5; // Normalized position (0.0 to 1.0)
  double _playerSize = 70.0;

  // Game objects
  List<Alien> _aliens = [];
  List<Bullet> _bullets = [];
  List<Explosion> _explosions = [];

  // Screen dimensions
  double _screenWidth = 0;
  double _screenHeight = 0;

  // Monster types
  final List<String> _monsterTypes = [
    'assets/image/monster1.png', // Yellow monster
    'assets/image/monster2.png', // Red demon
    'assets/image/monster3.png', // Blue monster
  ];

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _gameController = AnimationController(
      duration: Duration(milliseconds: 16), // ~60 FPS
      vsync: this,
    );
    _explosionController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _gameController.dispose();
    _explosionController.dispose();
    if (_gameStarted) {
      _gameTimer.cancel();
      _alienSpawnTimer.cancel();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
      _gameOver = false;
      _score = 0;
      _gameSpeed = 0.7; // Reset to 0.7
      _level = 1;
      _aliens.clear();
      _bullets.clear();
      _explosions.clear();
      _playerX = 0.5;
    });

    // Focus for keyboard input
    _focusNode.requestFocus();

    // Main game loop
    _gameTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      _updateGame();
    });

    // Alien spawn timer - gets faster over time
    _alienSpawnTimer = Timer.periodic(Duration(milliseconds: 1200), (timer) {
      _spawnAlien();
    });

    _gameController.repeat();
  }

  void _updateGame() {
    if (_gameOver) return;

    setState(() {
      // Update bullets - bullet speed 11.0 (constant)
      _bullets.removeWhere((bullet) {
        bullet.y -= 11.0; // Fixed bullet speed
        return bullet.y < 0;
      });

      // Update aliens
      _aliens.removeWhere((alien) {
        alien.y += alien.speed * _gameSpeed;
        if (alien.y > _screenHeight) {
          _endGame();
          return true;
        }
        return false;
      });

      // Update explosions
      _explosions.removeWhere((explosion) {
        explosion.timer -= 16;
        return explosion.timer <= 0;
      });

      // Check collisions
      _checkCollisions();

      // Level progression - cap game speed between 0.7 and 1.0
      if (_score > 0 && _score % 100 == 0 && _score / 100 > _level - 1) {
        _level++;
        _gameSpeed = (_gameSpeed + 0.05).clamp(
          0.7,
          1.0,
        ); // Increase slowly and cap at 1.0
        // Spawn rate increases with level
        _alienSpawnTimer.cancel();
        _alienSpawnTimer = Timer.periodic(
          Duration(milliseconds: (1200 / _level).round().clamp(300, 1200)),
          (timer) => _spawnAlien(),
        );
      }
    });
  }

  void _spawnAlien() {
    if (_gameOver) return;

    setState(() {
      _aliens.add(
        Alien(
          x: _random.nextDouble() * (_screenWidth - 60),
          y: -60,
          speed:
              1.0 +
              _random.nextDouble() * 2.0 +
              (_level * 0.25), // Reduced alien speed
          type: _monsterTypes[_random.nextInt(_monsterTypes.length)],
        ),
      );
    });
  }

  void _checkCollisions() {
    for (int i = _bullets.length - 1; i >= 0; i--) {
      for (int j = _aliens.length - 1; j >= 0; j--) {
        if (_isColliding(_bullets[i], _aliens[j])) {
          // Create explosion effect
          _explosions.add(
            Explosion(x: _aliens[j].x + 30, y: _aliens[j].y + 30, timer: 500),
          );

          _bullets.removeAt(i);
          _aliens.removeAt(j);
          _score += 10 + (_level * 5); // More points per level
          break;
        }
      }
    }
  }

  bool _isColliding(Bullet bullet, Alien alien) {
    return (bullet.x - (alien.x + 30)).abs() < 35 &&
        (bullet.y - (alien.y + 30)).abs() < 35;
  }

  void _handleKeyPress(RawKeyEvent event) {
    if (!_gameStarted || _gameOver) return;

    if (event is RawKeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
        case LogicalKeyboardKey.keyA:
          _movePlayer(-0.08);
          break;
        case LogicalKeyboardKey.arrowRight:
        case LogicalKeyboardKey.keyD:
          _movePlayer(0.08);
          break;
        case LogicalKeyboardKey.space:
        case LogicalKeyboardKey.arrowUp:
        case LogicalKeyboardKey.keyW:
          _shoot();
          break;
      }
    }
  }

  void _shoot() {
    if (_gameOver || !_gameStarted) return;

    setState(() {
      _bullets.add(
        Bullet(
          x: _playerX * _screenWidth,
          y:
              _screenHeight -
              180, // Moved bullets higher to match spaceship position
        ),
      );
    });
  }

  void _movePlayer(double delta) {
    setState(() {
      _playerX = (_playerX + delta).clamp(0.0, 1.0);
    });
  }

  void _endGame() {
    _gameOver = true;
    _gameTimer.cancel();
    _alienSpawnTimer.cancel();
    _gameController.stop();
  }

  void _resetGame() {
    setState(() {
      _gameStarted = false;
      _gameOver = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _handleKeyPress,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _screenWidth = constraints.maxWidth;
            _screenHeight = constraints.maxHeight;

            return Stack(
              children: [
                // Animated starfield background
                _buildAnimatedStarfield(),

                // Game area
                if (_gameStarted) _buildGameArea(),

                // UI overlay
                _buildUI(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedStarfield() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          colors: [
            Colors.indigo.shade900,
            Colors.purple.shade900,
            Colors.black,
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _gameController,
        builder: (context, child) {
          return CustomPaint(
            painter: AnimatedStarfieldPainter(_gameController.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  Widget _buildGameArea() {
    return Stack(
      children: [
        // Player spaceship - moved higher to be above fire button
        Positioned(
          left: _playerX * _screenWidth - _playerSize / 2,
          bottom: 130, // Moved from 70 to 130 to be above fire button
          child: _buildSpaceship(),
        ),

        // Bullets with glow effect
        ..._bullets.map(
          (bullet) => Positioned(
            left: bullet.x - 8,
            top: bullet.y,
            child: _buildBullet(),
          ),
        ),

        // Aliens with your monster images
        ..._aliens.map(
          (alien) => Positioned(
            left: alien.x,
            top: alien.y,
            child: _buildAlien(alien),
          ),
        ),

        // Explosion effects
        ..._explosions.map(
          (explosion) => Positioned(
            left: explosion.x - 40,
            top: explosion.y - 40,
            child: _buildExplosion(),
          ),
        ),
      ],
    );
  }

  Widget _buildSpaceship() {
    return SizedBox(
      width: _playerSize,
      height: _playerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Engine glow effect
          Container(
            width: _playerSize + 10,
            height: _playerSize + 10,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          // Your spaceship image
          Image.asset(
            'assets/image/spaceship.png',
            width: _playerSize,
            height: _playerSize,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _buildBullet() {
    return Container(
      width: 6,
      height: 16,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.yellow, Colors.orange, Colors.red],
        ),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow.withOpacity(0.8),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildAlien(Alien alien) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Menacing glow effect
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
          // Monster image
          Image.asset(alien.type, width: 60, height: 60, fit: BoxFit.contain),
        ],
      ),
    );
  }

  Widget _buildExplosion() {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(painter: ExplosionPainter()),
    );
  }

  Widget _buildUI() {
    return SafeArea(
      child: Column(
        children: [
          // Enhanced game stats
          if (_gameStarted) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SCORE: $_score',
                        style: TextStyle(
                          color: Colors.cyan,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.cyan.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Level $_level',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'SPEED: ${_gameSpeed.toStringAsFixed(1)}x',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Enemies: ${_aliens.length}',
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          Spacer(),

          // Enhanced Game over screen
          if (_gameOver) ...[
            Container(
              padding: EdgeInsets.all(32),
              margin: EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.withOpacity(0.9),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '💀 GAME OVER 💀',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.red, blurRadius: 10)],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Final Score: $_score',
                    style: TextStyle(
                      color: Colors.cyan,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Level Reached: $_level',
                    style: TextStyle(color: Colors.orange, fontSize: 18),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _resetGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      '🚀 RETRY',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Enhanced Start screen
          if (!_gameStarted && !_gameOver) ...[
            Container(
              padding: EdgeInsets.all(32),
              margin: EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyan.withOpacity(0.2),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyan, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '🚀 MONSTER DESTROYER',
                    style: TextStyle(
                      color: Colors.cyan,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.cyan.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '👾 Destroy the monster invasion!\n🎮 Use Arrow Keys or WASD to move\n🔥 SPACE to fire lasers',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      padding: EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      '⚡ START BATTLE',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Touch controls (backup for mobile)
          if (_gameStarted && !_gameOver) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Move left
                  GestureDetector(
                    onTap: () => _movePlayer(-0.08),
                    onPanUpdate: (details) => _movePlayer(-0.005),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.blue.withOpacity(0.6),
                            Colors.blue.withOpacity(0.2),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_left,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                  ),

                  // Fire button
                  GestureDetector(
                    onTap: _shoot,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.red.withOpacity(0.8),
                            Colors.orange.withOpacity(0.4),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flash_on, color: Colors.white, size: 35),
                          Text(
                            'FIRE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Move right
                  GestureDetector(
                    onTap: () => _movePlayer(0.08),
                    onPanUpdate: (details) => _movePlayer(0.005),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.blue.withOpacity(0.6),
                            Colors.blue.withOpacity(0.2),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_right,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Enhanced game object classes
class Alien {
  double x, y, speed;
  String type;
  Alien({
    required this.x,
    required this.y,
    required this.speed,
    required this.type,
  });
}

class Bullet {
  double x, y;
  Bullet({required this.x, required this.y});
}

class Explosion {
  double x, y;
  int timer;
  Explosion({required this.x, required this.y, required this.timer});
}

// Enhanced custom painters
class AnimatedStarfieldPainter extends CustomPainter {
  final double animationValue;

  AnimatedStarfieldPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = Random(42); // Fixed seed for consistent stars

    for (int i = 0; i < 150; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = random.nextDouble() * 2 + 0.5;
      final y = (baseY + animationValue * speed * 100) % size.height;

      final opacity =
          (random.nextDouble() * 0.8 + 0.2) *
          (0.5 + 0.5 * sin(animationValue * 10 + i));

      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), random.nextDouble() * 2 + 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class ExplosionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = Random();

    // Draw explosion particles
    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * 2 * pi;
      final distance = random.nextDouble() * 30 + 10;
      final x = size.width / 2 + cos(angle) * distance;
      final y = size.height / 2 + sin(angle) * distance;

      paint.color = [
        Colors.red,
        Colors.orange,
        Colors.yellow,
      ][random.nextInt(3)].withOpacity(random.nextDouble() * 0.8 + 0.2);

      canvas.drawCircle(Offset(x, y), random.nextDouble() * 4 + 2, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
