import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // உண்மையான மரியோ போல Landscape மோடிற்கு மாற்ற
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MarioApp());
}

class MarioApp extends StatefulWidget {
  const MarioApp({super.key});

  @override
  State<MarioApp> createState() => _MarioAppState();
}

class _MarioAppState extends State<MarioApp> {
  late MarioCloneGame game;

  @override
  void initState() {
    super.initState();
    game = MarioCloneGame();
  }

  void _restartGame() {
    setState(() {
      game = MarioCloneGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            GameWidget(game: game),
            // மேல் பகுதி HUD (Score, Coins, World)
            Positioned(
              top: 16,
              left: 30,
              right: 30,
              child: ValueListenableBuilder<int>(
                valueListenable: game.coinsNotifier,
                builder: (context, coins, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _hudText('MARIO\n${(coins * 200).toString().padLeft(6, '0')}'),
                      _hudText('🪙 x ${coins.toString().padLeft(2, '0')}'),
                      _hudText('WORLD\n1-1'),
                    ],
                  );
                },
              ),
            ),
            // ஜெயித்தால் அல்லது தோற்றால் வரும் பாப்-அப்
            ValueListenableBuilder<String?>(
              valueListenable: game.statusNotifier,
              builder: (context, status, _) {
                if (status == null) return const SizedBox.shrink();
                return Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber, width: 4),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          status,
                          style: const TextStyle(
                            fontSize: 32,
                            color: Colors.amber,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: _restartGame,
                          icon: const Icon(Icons.replay, color: Colors.white),
                          label: const Text(
                            'PLAY AGAIN',
                            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // கண்ட்ரோல் பட்டன்கள்
            Positioned(
              bottom: 20,
              left: 30,
              right: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _controlBtn(
                        Icons.arrow_back_ios_new,
                        () => game.mario.moveDir = -1,
                        () => game.mario.moveDir = 0,
                      ),
                      const SizedBox(width: 24),
                      _controlBtn(
                        Icons.arrow_forward_ios,
                        () => game.mario.moveDir = 1,
                        () => game.mario.moveDir = 0,
                      ),
                    ],
                  ),
                  _controlBtn(
                    Icons.arrow_upward,
                    () => game.mario.jump(),
                    () {},
                    color: Colors.redAccent.withOpacity(0.85),
                    label: 'JUMP',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hudText(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 1.5,
        shadows: [
          Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2)),
        ],
      ),
    );
  }

  Widget _controlBtn(
    IconData icon,
    VoidCallback onDown,
    VoidCallback onUp, {
    Color color = Colors.black45,
    String? label,
  }) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: () => onUp(),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.9), Colors.black87],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white70, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(2, 4)),
          ],
        ),
        child: Center(
          child: label != null
              ? Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))
              : Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

class MarioCloneGame extends FlameGame with HasCollisionDetection {
  late MarioPlayer mario;
  final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String?> statusNotifier = ValueNotifier<String?>(null);

  // கேமரா நகர்வதற்காக உலகின் தரை மட்டம்
  final double groundY = 320;

  @override
  Color backgroundColor() => const Color(0xFF5C94FC); // Sky Blue

  @override
  Future<void> onLoad() async {
    // 1. 3D மலைகள் மற்றும் மேகங்கள் (Background Scenery)
    for (int i = 0; i < 8; i++) {
      world.add(CloudComponent(Vector2(150.0 + i * 350, 60.0 + (i % 2) * 40)));
      world.add(HillComponent(Vector2(80.0 + i * 420, groundY)));
    }

    // 2. நீளமான 3D தரை (Ground with Grass & Blocks)
    world.add(GroundBlock(Vector2(-200, groundY), Vector2(1200, 200)));
    // நடுவே குழி (Pit)
    world.add(GroundBlock(Vector2(1120, groundY), Vector2(1800, 200)));

    // 3. பச்சை நிற பைப்புகள் (3D Green Pipes)
    world.add(PipeBlock(Vector2(420, groundY - 70), Vector2(64, 70)));
    world.add(PipeBlock(Vector2(820, groundY - 95), Vector2(64, 95)));
    world.add(PipeBlock(Vector2(1550, groundY - 80), Vector2(64, 80)));

    // 4. செங்கற்கள் & '?' சர்ப்ரைஸ் பிளாக்குகள் (Bricks & Question Blocks)
    _addBrickRow(260, groundY - 110, [false, true, false, true, false]);
    _addBrickRow(600, groundY - 120, [true, false, true]);
    _addBrickRow(640, groundY - 210, [false, true, false]);
    _addBrickRow(1250, groundY - 115, [false, false, true, false]);
    _addBrickRow(1720, groundY - 130, [true, true, true]);

    // 5. காயின்கள் (3D Gold Coins)
    for (int i = 0; i < 5; i++) {
      world.add(CoinComponent(Vector2(430.0 + i * 35, groundY - 130)));
      world.add(CoinComponent(Vector2(1300.0 + i * 40, groundY - 180)));
    }

    // 6. எதிரிகள் (Goombas)
    world.add(GoombaEnemy(Vector2(350, groundY - 36), 220, 400));
    world.add(GoombaEnemy(Vector2(700, groundY - 36), 500, 800));
    world.add(GoombaEnemy(Vector2(1400, groundY - 36), 1150, 1520));
    world.add(GoombaEnemy(Vector2(1900, groundY - 36), 1650, 2100));

    // 7. வின்னிங் கொடிக்கம்பம் மற்றும் கோட்டை (Flagpole & Castle)
    world.add(FlagPoleComponent(Vector2(2250, groundY - 240)));
    world.add(CastleComponent(Vector2(2360, groundY - 160)));

    // 8. மரியோ பிளேயர்
    mario = MarioPlayer(Vector2(100, groundY - 60));
    world.add(mario);

    // மரியோ செல்லச் செல்ல கேமராவும் கூடவே நகர
    camera.viewfinder.anchor = const Anchor(0.25, 0.65);
    camera.follow(mario, horizontalOnly: true);
  }

  void _addBrickRow(double startX, double y, List<bool> questionBlocks) {
    for (int i = 0; i < questionBlocks.length; i++) {
      world.add(
        BrickBlock(
          Vector2(startX + i * 38, y),
          isQuestion: questionBlocks[i],
        ),
      );
    }
  }
}

// ==================== 3D MARIO CHARACTER ====================
class MarioPlayer extends PositionComponent with CollisionCallbacks, HasGameRef<MarioCloneGame> {
  Vector2 velocity = Vector2.zero();
  final double gravity = 1100;
  final double jumpForce = -520;
  final double speed = 230;
  int moveDir = 0;
  bool facingRight = true;
  bool isOnGround = false;
  double walkAnim = 0;

  MarioPlayer(Vector2 position) : super(position: position, size: Vector2(36, 48));

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.statusNotifier.value != null) return;

    velocity.x = moveDir * speed;
    if (moveDir != 0) {
      facingRight = moveDir > 0;
      walkAnim += dt * 12;
    } else {
      walkAnim = 0;
    }

    velocity.y += gravity * dt;
    position += velocity * dt;

    if (position.x < 0) position.x = 0;

    // குழியில் விழுந்தால் Game Over
    if (position.y > gameRef.groundY + 120) {
      gameRef.statusNotifier.value = 'GAME OVER 💥';
    }
  }

  void jump() {
    if (isOnGround && gameRef.statusNotifier.value == null) {
      velocity.y = jumpForce;
      isOnGround = false;
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is SolidBlock) {
      final myRect = toRect();
      final otherRect = other.toRect();
      final overlap = myRect.intersect(otherRect);

      if (overlap.width <= 0 || overlap.height <= 0) return;

      if (overlap.width > overlap.height) {
        if (myRect.center.dy < otherRect.center.dy && velocity.y >= 0) {
          // பிளாக் மீது நிற்பது
          position.y = other.position.y - size.y;
          velocity.y = 0;
          isOnGround = true;
        } else if (myRect.center.dy > otherRect.center.dy && velocity.y < 0) {
          // கீழே இருந்து பிளாக்கை தலையால் முட்டுவது
          position.y = other.position.y + other.size.y;
          velocity.y = 40;
          if (other is BrickBlock) {
            other.hitFromBelow(gameRef);
          }
        }
      } else {
        // சைடில் மோதுவது
        if (myRect.center.dx < otherRect.center.dx) {
          position.x = other.position.x - size.x;
        } else {
          position.x = other.position.x + other.size.x;
        }
      }
    } else if (other is CoinComponent) {
      other.removeFromParent();
      gameRef.coinsNotifier.value += 1;
    } else if (other is GoombaEnemy) {
      if (velocity.y > 0 && position.y + size.y - other.position.y < 22) {
        // எதிரியின் தலையில் குதித்து அழிப்பது
        other.removeFromParent();
        velocity.y = jumpForce * 0.65;
        gameRef.coinsNotifier.value += 2;
      } else {
        gameRef.statusNotifier.value = 'GAME OVER 💥';
      }
    } else if (other is FlagPoleComponent) {
      gameRef.statusNotifier.value = 'COURSE CLEAR! 🏆';
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    if (!facingRight) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    // 1. காலணிகள் (3D Brown Boots)
    final double legOffset = (walkAnim % 2 > 1) ? 4 : -4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(4 + (moveDir != 0 ? legOffset : 0), 40, 12, 8), const Radius.circular(4)),
      Paint()..color = const Color(0xFF5D2906),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(20 - (moveDir != 0 ? legOffset : 0), 40, 12, 8), const Radius.circular(4)),
      Paint()..color = const Color(0xFF7B380B),
    );

    // 2. சிவப்பு சட்டை (Red Shirt)
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(4, 22, 28, 16), const Radius.circular(6)),
      Paint()..color = const Color(0xFFE52521),
    );

    // 3. நீல ஓவர்ஆல்ஸ் & மஞ்சள் பட்டன்கள் (Blue Overalls with 3D Gradient)
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(8, 24, 20, 18), const Radius.circular(5)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF2B5BF2), Color(0xFF002699)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(8, 24, 20, 18)),
    );
    canvas.drawCircle(const Offset(13, 31), 2.5, Paint()..color = Colors.amber);
    canvas.drawCircle(const Offset(23, 31), 2.5, Paint()..color = Colors.amber);

    // 4. முகம், மூக்கு மற்றும் மீசை (Face, Nose & Mustache)
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(7, 8, 22, 16), const Radius.circular(7)),
      Paint()..color = const Color(0xFFFFCC99),
    );
    // பெரிய மூக்கு
    canvas.drawOval(const Rect.fromLTWH(24, 13, 9, 6), Paint()..color = const Color(0xFFFFB070));
    // கண்கள்
    canvas.drawOval(const Rect.fromLTWH(21, 10, 3, 5), Paint()..color = Colors.black);
    // மீசை
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(18, 18, 13, 4), const Radius.circular(2)),
      Paint()..color = const Color(0xFF4A2000),
    );

    // 5. மரியோவின் சிவப்பு தொப்பி (3D Red Cap)
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(5, 2, 24, 8), const Radius.circular(5)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF4D4D), Color(0xFFB30000)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(const Rect.fromLTWH(5, 2, 24, 8)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(16, 6, 18, 4), const Radius.circular(2)),
      Paint()..color = const Color(0xFFCC0000),
    );

    canvas.restore();
  }
}

// ==================== BLOCKS & PIPES ====================
abstract class SolidBlock extends PositionComponent {
  SolidBlock(Vector2 position, Vector2 size) : super(position: position, size: size);

  @override
  Future<void> onLoad() async => add(RectangleHitbox());
}

class GroundBlock extends SolidBlock {
  GroundBlock(super.position, super.size);

  @override
  void render(Canvas canvas) {
    // மண் பகுதி (3D Shaded Soil)
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFC84C0C), Color(0xFF6E2602)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(size.toRect()),
    );
    // மேலே பச்சை புல்வெளி (3D Grass Layer)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, 14),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF73E600), Color(0xFF288A00)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.x, 14)),
    );
  }
}

class PipeBlock extends SolidBlock {
  PipeBlock(super.position, super.size);

  @override
  void render(Canvas canvas) {
    // 3D Cylindrical Metallic Green Shader
    final pipeShader = const LinearGradient(
      colors: [Color(0xFF007A00), Color(0xFF88FF44), Color(0xFF00A800), Color(0xFF004D00)],
      stops: [0.0, 0.3, 0.7, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));

    // பைப்பின் கீழ் பகுதி
    canvas.drawRect(Rect.fromLTWH(4, 24, size.x - 8, size.y - 24), Paint()..shader = pipeShader);
    canvas.drawRect(
      Rect.fromLTWH(4, 24, size.x - 8, size.y - 24),
      Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 2,
    );

    // பைப்பின் மேல் வாய் பகுதி (Pipe Rim)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, 24), const Radius.circular(4)),
      Paint()..shader = pipeShader,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, 24), const Radius.circular(4)),
      Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 2,
    );
  }
}

class BrickBlock extends SolidBlock {
  bool isQuestion;
  bool isUsed = false;

  BrickBlock(Vector2 position, {this.isQuestion = false}) : super(position, Vector2(38, 38));

  void hitFromBelow(MarioCloneGame game) {
    if (isQuestion && !isUsed) {
      isUsed = true;
      game.coinsNotifier.value += 1;
      // மேலே காயின் துள்ளி வரும் எஃபெக்ட்
      game.world.add(CoinComponent(Vector2(position.x + 7, position.y - 34)));
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    if (isQuestion && !isUsed) {
      // 3D Gold '?' Block
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFEA70), Color(0xFFE68A00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
      );
      final tp = TextPainter(
        text: const TextSpan(
          text: '?',
          style: TextStyle(color: Color(0xFF5A2D00), fontSize: 24, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, const Offset(12, 5));
    } else if (isUsed) {
      // காலியான பிளாக்
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()..color = const Color(0xFF8C7355),
      );
    } else {
      // செங்கல் (Brick Pattern)
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFD25216), Color(0xFF8F3205)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
      );
      canvas.drawLine(const Offset(0, 19), const Offset(38, 19), Paint()..color = Colors.black45..strokeWidth = 2);
      canvas.drawLine(const Offset(19, 0), const Offset(19, 19), Paint()..color = Colors.black45..strokeWidth = 2);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 2,
    );
  }
}

// ==================== COINS, ENEMIES & FLAGPOLE ====================
class CoinComponent extends PositionComponent {
  CoinComponent(Vector2 position) : super(position: position, size: Vector2(24, 24));

  @override
  Future<void> onLoad() async => add(CircleHitbox());

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      const Rect.fromLTWH(3, 0, 18, 24),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFF99), Color(0xFFFFB300), Color(0xFFB26B00)],
        ).createShader(const Rect.fromLTWH(3, 0, 18, 24)),
    );
    canva
