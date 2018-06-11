import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fluttery/layout.dart';
import 'package:prototype/photos.dart';
import 'package:prototype/profiles.dart';

class CardStack extends StatefulWidget {
  final MatchEngine matchEngine;

  CardStack({
    this.matchEngine,
  });

  @override
  _CardStackState createState() => new _CardStackState();
}

class _CardStackState extends State<CardStack> {
  Key _frontCard;
  double _nextCardScale = 0.9;
  Match _currentMatch;

  @override
  void initState() {
    super.initState();
    widget.matchEngine.addListener(_onMatchEngineChange);

    _currentMatch = widget.matchEngine.currentMatch;
    _currentMatch.addListener(_onMatchChange);

    _frontCard = new Key(_currentMatch.profile.name);
  }

  @override
  void dispose() {
    _currentMatch.removeListener(_onMatchChange);
    widget.matchEngine.removeListener(_onMatchEngineChange);
    super.dispose();
  }

  void _onMatchEngineChange() {
    _currentMatch.removeListener(_onMatchChange);
    _currentMatch = widget.matchEngine.currentMatch;
    _currentMatch.addListener(_onMatchChange);

    _frontCard = new Key(_currentMatch.profile.name);

    setState(() {/* current match may have switched, re-render */});
  }

  void _onMatchChange() {
    setState(() {/* current match may have changed state, re-render */});
  }

  SlideDirection _desiredSlideOutDirection() {
    switch (widget.matchEngine.currentMatch.decision) {
      case Decision.nope:
        return SlideDirection.left;
      case Decision.like:
        return SlideDirection.right;
      case Decision.superLike:
        return SlideDirection.up;
      default:
        return null;
    }
  }

  Widget _buildBackCard() {
    return new Transform(
      transform: new Matrix4.identity()..scale(_nextCardScale, _nextCardScale),
      alignment: Alignment.center,
      child: new ProfileCard(
        profile: widget.matchEngine.nextMatch.profile,
      ),
    );
  }

  Widget _buildFrontCard() {
    return new ProfileCard(
      key: _frontCard,
      profile: widget.matchEngine.currentMatch.profile,
    );
  }

  void _onSlideUpdate(double slideDistance) {
    setState(() {
      _nextCardScale = 0.9 + (0.1 * (slideDistance / 100.0)).clamp(0.0, 0.1);
    });
  }

  void _onSlideOutComplete(SlideDirection direction) {
    Match currentMatch = widget.matchEngine.currentMatch;

    switch (direction) {
      case SlideDirection.left:
        if (currentMatch.decision != Decision.nope) {
          currentMatch.nope();
        }
        break;
      case SlideDirection.right:
        if (currentMatch.decision != Decision.like) {
          currentMatch.like();
        }
        break;
      case SlideDirection.up:
        if (currentMatch.decision != Decision.superLike) {
          currentMatch.superLike();
        }
        break;
    }

    widget.matchEngine.cycleMatch();
  }

  @override
  Widget build(BuildContext context) {
    return new Stack(
      children: <Widget>[
        new DraggableCard(
          card: _buildBackCard(),
          isDraggable: false,
        ),
        new DraggableCard(
          card: _buildFrontCard(),
          slideTo: _desiredSlideOutDirection(),
          onSlideUpdate: _onSlideUpdate,
          onSlideOutComplete: _onSlideOutComplete,
        ),
      ],
    );
  }
}

class DraggableCard extends StatefulWidget {
  final Widget card;
  final bool isDraggable;
  final SlideDirection slideTo;
  final Function(double distance) onSlideUpdate;
  final Function(SlideDirection direction) onSlideOutComplete;

  DraggableCard({
    this.card,
    this.isDraggable = true,
    this.onSlideUpdate,
    this.onSlideOutComplete,
    this.slideTo,
  });

  @override
  _DraggableCardState createState() => new _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard> with TickerProviderStateMixin {
  GlobalKey profileCardKey = new GlobalKey(debugLabel: 'profile_card_key');
  Offset cardOffset = const Offset(0.0, 0.0);
  SlideDirection slideDirection;
  Offset dragStart;
  Offset dragBackStart;
  Offset dragPosition;
  AnimationController dragBackAnimation;
  Tween<Offset> dragOutTween;
  AnimationController dragOutAnimation;

  @override
  void initState() {
    super.initState();

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

            if (null != widget.onSlideUpdate) {
              widget.onSlideUpdate(cardOffset.distance);
            }
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

          if (null != widget.onSlideUpdate) {
            widget.onSlideUpdate(cardOffset.distance);
          }
        });
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            dragStart = null;
            dragOutTween = null;
            dragPosition = null;

            if (null != widget.onSlideOutComplete) {
              widget.onSlideOutComplete(slideDirection);
            }
          });
        }
      });
  }

  @override
  void didUpdateWidget(DraggableCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.card.key != oldWidget.card.key) {
      cardOffset = const Offset(0.0, 0.0);
    }

    WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
      if (oldWidget.slideTo == null && widget.slideTo != null) {
        switch (widget.slideTo) {
          case SlideDirection.left:
            _slideLeft();
            break;
          case SlideDirection.right:
            _slideRight();
            break;
          case SlideDirection.up:
            _slideUp();
            break;
        }
      }
    });
  }

  @override
  void dispose() {
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

  void _slideLeft() {
    final screenWidth = context.size.width;
    dragStart = _chooseRandomDragStart();
    dragOutTween = new Tween(begin: const Offset(0.0, 0.0), end: new Offset(-2 * screenWidth, 0.0));
    dragOutAnimation.forward(from: 0.0);
  }

  void _slideRight() {
    final screenWidth = context.size.width;
    dragStart = _chooseRandomDragStart();
    dragOutTween = new Tween(begin: const Offset(0.0, 0.0), end: new Offset(2 * screenWidth, 0.0));
    dragOutAnimation.forward(from: 0.0);
  }

  void _slideUp() {
    final screenHeight = context.size.width;
    dragStart = _chooseRandomDragStart();
    dragOutTween =
        new Tween(begin: const Offset(0.0, 0.0), end: new Offset(0.0, -2 * screenHeight));
    dragOutAnimation.forward(from: 0.0);
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

      if (null != widget.onSlideUpdate) {
        widget.onSlideUpdate(cardOffset.distance);
      }
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

        slideDirection = isInNopeRegion ? SlideDirection.left : SlideDirection.right;
      } else if (isInSuperLikeRegion) {
        dragOutTween = new Tween(begin: cardOffset, end: dragVector * (2 * context.size.height));
        dragOutAnimation.forward(from: 0.0);

        slideDirection = SlideDirection.up;
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

  @override
  Widget build(BuildContext context) {
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
            child: new GestureDetector(
              onPanStart: widget.isDraggable ? _onPanStart : null,
              onPanUpdate: widget.isDraggable ? _onPanUpdate : null,
              onPanEnd: widget.isDraggable ? _onPanEnd : null,
              child: new Container(
                key: profileCardKey,
                width: anchorBounds.width,
                height: anchorBounds.height,
                padding: const EdgeInsets.all(16.0),
                child: widget.card,
              ),
            ),
          ),
        );
      },
    );
  }
}

enum SlideDirection {
  left,
  right,
  up,
}

class MatchEngine extends ChangeNotifier {
  final List<Match> _profiles;
  int _currentMatchIndex;
  int _nextMatchIndex;

  MatchEngine({
    List<Match> matches,
  }) : _profiles = matches {
    _currentMatchIndex = 0;
    _nextMatchIndex = 1;
  }

  Match get currentMatch => _profiles[_currentMatchIndex];

  Match get nextMatch => _profiles[_nextMatchIndex];

  void cycleMatch() {
    if (currentMatch.decision != Decision.undecided) {
      // This needs to come after removing the listener to avoid invoking this method again.
      currentMatch.reset();

      _currentMatchIndex = _nextMatchIndex;
      _nextMatchIndex = _nextMatchIndex < _profiles.length - 1 ? _nextMatchIndex + 1 : 0;

      notifyListeners();
    }
  }
}

class Match extends ChangeNotifier {
  final Profile profile;
  Decision decision = Decision.undecided;

  Match({
    this.profile,
  });

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

class ProfileCard extends StatefulWidget {
  final Profile profile;

  ProfileCard({
    Key key,
    this.profile,
  }) : super(key: key);

  @override
  ProfileCardState createState() {
    return new ProfileCardState();
  }
}

class ProfileCardState extends State<ProfileCard> {
  Widget _buildBackground() {
    return new PhotoBrowser(
      photoAssetPaths: widget.profile.photos,
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
                  new Text(widget.profile.name,
                      style: new TextStyle(
                        color: Colors.white,
                        fontSize: 24.0,
                      )),
                  new Text(widget.profile.bio,
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
