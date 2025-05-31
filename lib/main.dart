// TM
//
// implemented using Flutter 5/27/25
//
// Fong (Flutter Pong)

import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fong',
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// HOMEPAGE

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Size screenSize;
  final FocusNode _focusNode = FocusNode();

  double paddleX = 0.0;
  double ballX = 0.0;
  double ballY = 0.0;
  double ballSpeedX = 5;
  double ballSpeedY = -5;
  double paddleWidth = 100;
  double paddleHeight = 20;
  int score = 0;

  List<Rect> bricks = [];
  bool initialized = false;

  Timer? _moveTimer;
  LogicalKeyboardKey? _heldKey;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: Duration(days: 999),
      vsync: this,
    )..addListener(gameLoop);
    controller.forward();
  }

// Initilizations

  void initializeGame(Size size) {
    screenSize = size;
    paddleX = (screenSize.width - paddleWidth) / 2;
    ballX = screenSize.width / 2 - 10;
    ballY = screenSize.height / 2;

    bricks.clear();
    double brickWidth = 45;
    double brickHeight = 20;
    double padding = 5;

    int columns = ((screenSize.width - padding) / (brickWidth + padding)).floor();
    int rows = 5;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        double x = padding + col * (brickWidth + padding);
        double y = padding + row * (brickHeight + padding) + 30;
        bricks.add(Rect.fromLTWH(x, y, brickWidth, brickHeight));
      }
    }

    initialized = true;
  }

// Main Game Loop

  void gameLoop() {
    if (!initialized) return;

    setState(() {
      ballX += ballSpeedX;
      ballY += ballSpeedY;

      // allows collisions with wall
      if (ballX <= 0 || ballX >= screenSize.width - 20) ballSpeedX *= -1;
      if (ballY <= 0) ballSpeedY *= -1;

      Rect paddle = Rect.fromLTWH(paddleX, screenSize.height - 40, paddleWidth, paddleHeight);
      Rect ballRect = Rect.fromLTWH(ballX, ballY, 20, 20);

      // paddle physics
      if (ballRect.overlaps(paddle)) {
        ballSpeedY = -ballSpeedY;
        double hitPoint = (ballX + 10) - (paddleX + paddleWidth / 2);
        ballSpeedX += hitPoint * 0.05;
      }

      // brick collision logic
      for (int i = bricks.length - 1; i >= 0; i--) {
        if (bricks[i].overlaps(ballRect)) {
          Rect brick = bricks[i];
          bricks.removeAt(i);
          score += 10;

          if ((ballY + 20 <= brick.top + 3) || (ballY >= brick.bottom - 3)) {
            ballSpeedY *= -1;
          } else {
            ballSpeedX *= -1;
          }

          break;
        }
      }

      // PLAYER LOSES
      if (ballY > screenSize.height) {
        controller.stop();
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Game Over!"),
            content: Text("Score: $score"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  resetGame();
                },
                child: Text("Play Again"),
              )
            ],
          ),
        );
      }
    });
  }

  void resetGame() {
    setState(() {
      initializeGame(screenSize);
      ballSpeedX = 5;
      ballSpeedY = -5;
      score = 0;
      controller.repeat();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _focusNode.dispose();
    _moveTimer?.cancel(); // stops timer, allows smooth movement with keys
    super.dispose();
  }

// Movement widget

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (!initialized) {
          initializeGame(Size(constraints.maxWidth, constraints.maxHeight));
        }

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              paddleX += details.delta.dx;
              paddleX = paddleX.clamp(0.0, screenSize.width - paddleWidth);
            });
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: RawKeyboardListener(
              focusNode: _focusNode,
              autofocus: true,
              onKey: (event) {
                const moveAmount = 10;
                if (event is RawKeyDownEvent) {
                  if (_heldKey != event.logicalKey) {
                    _heldKey = event.logicalKey;
                    _moveTimer?.cancel();
                    _moveTimer = Timer.periodic(Duration(milliseconds: 16), (_) {
                      setState(() {
                        if (_heldKey == LogicalKeyboardKey.arrowLeft) {
                          paddleX = max(paddleX - moveAmount, 0);
                        } else if (_heldKey == LogicalKeyboardKey.arrowRight) {
                          paddleX = min(paddleX + moveAmount, screenSize.width - paddleWidth);
                        }
                      });
                    });
                  }
                } else if (event is RawKeyUpEvent) {
                  if (_heldKey == event.logicalKey) {
                    _moveTimer?.cancel();
                    _heldKey = null;
                  }
                }
              },
              child: CustomPaint(
                painter: GamePainter(paddleX, ballX, ballY, bricks, score),
                child: Container(),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Paint

class GamePainter extends CustomPainter {
  final double paddleX, ballX, ballY;
  final List<Rect> bricks;
  final int score;

  GamePainter(this.paddleX, this.ballX, this.ballY, this.bricks, this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // paddle or player
    paint.color = const Color.fromARGB(255, 255, 255, 255);
    canvas.drawRect(Rect.fromLTWH(paddleX, size.height - 40, 100, 20), paint);

    // the ball
    paint.color = Colors.white;
    canvas.drawOval(Rect.fromLTWH(ballX, ballY, 20, 20), paint);

    // brick
    paint.color = const Color.fromARGB(255, 255, 255, 255);
    for (var brick in bricks) {
      canvas.drawRect(brick, paint);
    }

    // score 
    final textStyle = TextStyle(color: Colors.white, fontSize: 18);
    final textSpan = TextSpan(text: 'Score: $score', style: textStyle);
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout(minWidth: 0, maxWidth: size.width);
    textPainter.paint(canvas, Offset(10, 10));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
