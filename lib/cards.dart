import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fluttery/layout.dart';
import 'package:prototype/photos.dart';

class DraggableCard extends StatefulWidget {
  final Match match;

  DraggableCard({
    this.match,
  });

  @override
  _DraggableCardState createState() => new _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard> with TickerProviderStateMixin {
  Decision decision;
  GlobalKey profileCardKey = new GlobalKey(debugLabel: 'profile_card_key');
  Offset cardOffset = const Offset(0.0, 0.0);
  Offset dragStart;
  Offset dragBackStart;
  Offset dragPosition;
  AnimationController dragBackAnimation;
  Tween<Offset> dragOutTween;
  AnimationController dragOutAnimation;

  @override
  void initState() {
    super.initState();

    decision = widget.match.decision;

    dragBackAnimation = new AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )
      ..addListener(() => setState(() {
            cardOffset = Offset.lerp(
              dragBackStart,
              const Offset(0.0, 0.0),
              Curves.elasticOut.transform(dragBackAnimation.value),
            );
          }))
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          dragStart = null;
          dragBackStart = null;
          dragPosition = null;
        }
      });

    dragOutAnimation = new AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )
      ..addListener(() {
        setState(() {
          cardOffset = dragOutTween.evaluate(dragOutAnimation);
        });
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            dragStart = null;
            dragOutTween = null;
            dragPosition = null;
            cardOffset = const Offset(0.0, 0.0);

            widget.match.reset();
          });
        }
      });

    widget.match.addListener(_onMatchChange);
  }

  @override
  void didUpdateWidget(DraggableCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.match != oldWidget.match) {
      oldWidget.match.removeListener(_onMatchChange);
      widget.match.addListener(_onMatchChange);
    }
  }

  @override
  void dispose() {
    widget.match.removeListener(_onMatchChange);
    dragBackAnimation.dispose();
    super.dispose();
  }

  Offset _chooseRandomDragStart() {
    final cardContext = profileCardKey.currentContext;
    final cardTopLeft =
        (cardContext.findRenderObject() as RenderBox).localToGlobal(const Offset(0.0, 0.0));
    final dragStartY =
        cardContext.size.height * (new Random().nextDouble() < 0.5 ? 0.25 : 0.75) + cardTopLeft.dy;
    return new Offset(cardContext.size.width / 2 + cardTopLeft.dx, dragStartY);
  }

  void _nope() {
    final screenWidth = context.size.width;
    dragStart = _chooseRandomDragStart();
    dragOutTween = new Tween(begin: const Offset(0.0, 0.0), end: new Offset(-2 * screenWidth, 0.0));
    dragOutAnimation.forward(from: 0.0);
  }

  void _like() {
    final screenWidth = context.size.width;
    dragStart = _chooseRandomDragStart();
    dragOutTween = new Tween(begin: const Offset(0.0, 0.0), end: new Offset(2 * screenWidth, 0.0));
    dragOutAnimation.forward(from: 0.0);
  }

  void _superLike() {
    final screenHeight = context.size.width;
    dragStart = _chooseRandomDragStart();
    dragOutTween =
        new Tween(begin: const Offset(0.0, 0.0), end: new Offset(0.0, -2 * screenHeight));
    dragOutAnimation.forward(from: 0.0);
  }

  void _onMatchChange() {
    if (widget.match.decision != decision) {
      switch (widget.match.decision) {
        case Decision.nope:
          _nope();
          break;
        case Decision.like:
          _like();
          break;
        case Decision.superLike:
          _superLike();
          break;
        default:
          break;
      }
    }

    decision = widget.match.decision;
  }

  void _onPanStart(DragStartDetails details) {
    dragStart = details.globalPosition;

    if (dragBackAnimation.isAnimating) {
      dragBackAnimation.stop(canceled: true);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      dragPosition = details.globalPosition;
      cardOffset = details.globalPosition - dragStart;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final dragVector = cardOffset / cardOffset.distance;
    final isInNopeRegion = (cardOffset.dx / context.size.width).abs() < -0.45;
    final isInLikeRegion = (cardOffset.dx / context.size.width).abs() > 0.45;
    final isInSuperLikeRegion = (cardOffset.dy / context.size.height) < -0.40;

    setState(() {
      if (isInNopeRegion || isInLikeRegion) {
        dragOutTween = new Tween(begin: cardOffset, end: dragVector * (2 * context.size.width));
        dragOutAnimation.forward(from: 0.0);
      } else if (isInSuperLikeRegion) {
        dragOutTween = new Tween(begin: cardOffset, end: dragVector * (2 * context.size.height));
        dragOutAnimation.forward(from: 0.0);
      } else {
        dragBackStart = cardOffset;
        dragBackAnimation.forward(from: 0.0);
      }
    });
  }

  double _rotation(Rect dragBounds) {
    if (dragStart != null) {
      final rotationCornerMultiplier =
          dragStart.dy >= dragBounds.top + (dragBounds.height / 2) ? -1 : 1;
      return (pi / 8) * (cardOffset.dx / dragBounds.width) * rotationCornerMultiplier;
    } else {
      return 0.0;
    }
  }

  Offset _rotationOrigin(Rect dragBounds) {
    if (dragStart != null) {
      return dragStart - dragBounds.topLeft;
    } else {
      return const Offset(0.0, 0.0);
    }
  }

  Widget _buildOverlay(Widget profileCard) {
    return new AnchoredOverlay(
      showOverlay: true,
      child: new Container(),
      // Builds an overlay centered on top of this widget.
      overlayBuilder: (BuildContext context, Rect anchorBounds, Offset anchor) {
        return CenterAbout(
          position: anchor,
          child: new Transform(
            transform: new Matrix4.translationValues(cardOffset.dx, cardOffset.dy, 0.0)
              ..rotateZ(_rotation(anchorBounds)),
            origin: _rotationOrigin(anchorBounds),
            child: new Container(
              key: profileCardKey,
              width: anchorBounds.width,
              height: anchorBounds.height,
              padding: const EdgeInsets.all(16.0),
              child: new GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: profileCard,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildOverlay(
      new ProfileCard(),
    );
  }
}

class Match extends ChangeNotifier {
  Decision decision = Decision.undecided;

  void like() {
    if (decision == Decision.undecided) {
      decision = Decision.like;
      notifyListeners();
    }
  }

  void nope() {
    if (decision == Decision.undecided) {
      decision = Decision.nope;
      notifyListeners();
    }
  }

  void superLike() {
    if (decision == Decision.undecided) {
      decision = Decision.superLike;
      notifyListeners();
    }
  }

  void reset() {
    decision = Decision.undecided;
    notifyListeners();
  }
}

enum Decision {
  undecided,
  nope,
  like,
  superLike,
}

class ProfileCard extends StatelessWidget {
  Widget _buildBackground() {
    return new PhotoBrowser(
      photoAssetPaths: [
        'assets/photo_1.jpg',
        'assets/photo_2.jpg',
        'assets/photo_3.jpg',
        'assets/photo_4.jpg',
      ],
      visiblePhotoIndex: 0,
    );
  }

  Widget _buildProfileSynopsis() {
    return new Positioned(
      left: 0.0,
      right: 0.0,
      bottom: 0.0,
      child: new Container(
        decoration: new BoxDecoration(
            gradient: new LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
        )),
        padding: const EdgeInsets.all(24.0),
        child: new Row(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            new Expanded(
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  new Text('First Last',
                      style: new TextStyle(
                        color: Colors.white,
                        fontSize: 24.0,
                      )),
                  new Text('Some description',
                      style: new TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                      )),
                ],
              ),
            ),
            new Icon(
              Icons.info,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: new BoxDecoration(
        borderRadius: new BorderRadius.circular(10.0),
        boxShadow: [
          new BoxShadow(
            color: const Color(0x11000000),
            blurRadius: 5.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: new BorderRadius.circular(10.0),
        child: new Material(
          child: new Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _buildBackground(),
              _buildProfileSynopsis(),
            ],
          ),
        ),
      ),
    );
  }
}
