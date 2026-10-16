import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MarioApp());
}

class MarioApp extends StatefulWidget {
  const MarioApp({super.key});

  @override
  State<MarioApp> createState() => _MarioAppState();
}

class _MarioAppState extends State<MarioApp> {
  late final MarioCloneGame game;

  @override
  void initState() {
    super.initState();
    game = MarioCloneGame();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            GameWidget(game: game),
            Positioned(
              top: 40,
              left: 20,
              child: ValueListenableBuilder<int>(
                valueListenable: game.scoreNotifier,
                builder: (context, score, _) {
                  return Text(
                    'COINS: $score',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _controlBtn(
                        Icons.arrow_back,
                        () => game.mario.moveDir = -1,
                        () => game.mario.moveDir = 0,
                      ),
                      const SizedBox(width: 20),
                      _controlBtn(
                        Icons.arrow_forward,
                        () => game.mario.moveDir = 1,
                        () => game.mario.moveDir = 0,
                      ),
                    ],
                  ),
                  _controlBtn(
                    Icons.arrow_upward,
                    () => game.mario.jump(),
                    () {},
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlBtn(
    IconData icon,
    VoidCallback onDown,
    VoidCallback onUp, {
    Color color = Colors.black54,
  }) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: () => onUp(),
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 34),
      ),
    );
  }
}

class MarioCloneGame extends FlameGame with HasCollisionDetection {
  late Player mario;
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);

  @override
  Future<void> onLoad() async {
    camera.backdrop.add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = const Color(0xFF5C94FC),
      ),
    );

    add(PlatformBlock(Vector2(0, size.y - 80), Vector2(size.x * 2, 80), const Color(0xFFC84C0C)));
    add(PlatformBlock(Vector2(140, size.y - 200), Vector2(110, 30), Colors.orange.shade800));
    add(PlatformBlock(Vector2(280, size.y - 290), Vector2(110, 30), Colors.orange.shade800));

    add(Coin(Vector2(180, size.y - 245)));
    add(Coin(Vector2(320, size.y - 335)));
    add(Coin(Vector2(240, size.y - 130)));

    add(Enemy(Vector2(250, size.y - 115)));

    mario = Player(Vector2(40, size.y - 150));
    add(mario);
  }
}

class Player extends PositionComponent with CollisionCallbacks, HasGameRef<MarioCloneGame> {
  Vector2 velocity = Vector2.zero();
  final double gravity = 1000;
  final double jumpForce = -480;
  final double speed = 200;
  int moveDir = 0;
  bool isOnGround = false;

  Player(Vector2 position) : super(position: position, size: Vector2(36, 44));

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    velocity.x = moveDir * speed;
    velocity.y += gravity * dt;
    position += velocity * dt;

    if (position.x < 0) position.x = 0;
    if (position.x > gameRef.size.x - size.x) position.x = gameRef.size.x - size.x;

    if (position.y >= gameRef.size.y - 80 - size.y) {
      position.y = gameRef.size.y - 80 - size.y;
      velocity.y = 0;
      isOnGround = true;
    }
  }

  void jump() {
    if (isOnGround) {
      velocity.y = jumpForce;
      isOnGround = false;
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is PlatformBlock) {
      if (velocity.y > 0 && position.y + size.y - velocity.y * 0.02 <= other.position.y + 12) {
        position.y = other.position.y - size.y;
        velocity.y = 0;
        isOnGround = true;
      }
    } else if (other is Coin) {
      other.removeFromParent();
      gameRef.scoreNotifier.value += 1;
    } else if (other is Enemy) {
      if (velocity.y > 0 && position.y + size.y - other.position.y < 20) {
        other.removeFromParent();
        velocity.y = jumpForce * 0.6;
        gameRef.scoreNotifier.value += 5;
      } else {
        position = Vector2(40, gameRef.size.y - 150);
        velocity = Vector2.zero();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = Colors.red.shade700);
    canvas.drawRect(const Rect.fromLTWH(20, 8, 12, 10), Paint()..color = const Color(0xFFFFDAB9));
  }
}

class PlatformBlock extends PositionComponent {
  final Color color;
  PlatformBlock(Vector2 position, Vector2 size, this.color) : super(position: position, size: size);

  @override
  Future<void> onLoad() async => add(RectangleHitbox());

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = color);
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

class Coin extends PositionComponent {
  Coin(Vector2 position) : super(position: position, size: Vector2(24, 24));

  @override
  Future<void> onLoad() async => add(CircleHitbox());

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(const Offset(12, 12), 12, Paint()..color = Colors.amber);
  }
}

class Enemy extends PositionComponent with HasGameRef<MarioCloneGame> {
  double dir = 1;
  Enemy(Vector2 position) : super(position: position, size: Vector2(34, 34));

  @override
  Future<void> onLoad() async => add(RectangleHitbox());

  @override
  void update(double dt) {
    super.update(dt);
    position.x += dir * 75 * dt;
    if (position.x > 340) dir = -1;
    if (position.x < 120) dir = 1;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), Paint()..color = Colors.brown.shade800);
  }
}
