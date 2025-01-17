import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'get_position.dart';
import 'layout_overlays.dart';
import 'shape_clipper.dart';
import 'showcase_widget.dart';
import 'tooltip_widget.dart';

class Showcase extends StatefulWidget {
  @override
  final GlobalKey key;

  final Widget child;
  final BuildContext context;
  final String title;
  final String description;
  final String skip;
  final VoidCallback skipFunction;
  final ShapeBorder shapeBorder;
  final BorderRadius radius;
  final TextStyle titleTextStyle;
  final TextStyle descTextStyle;
  final EdgeInsets contentPadding;
  final Color overlayColor;
  final double overlayOpacity;
  final Widget container;
  final Color showcaseBackgroundColor;
  final Color textColor;
  final bool showArrow;
  final double height;
  final double width;
  final Duration animationDuration;
  final VoidCallback onToolTipClick;
  final VoidCallback onTargetClick;
  final bool disposeOnTap;
  final bool disableAnimation;
  final EdgeInsets overlayPadding;
  final double blurValue;

  const Showcase({
    @required this.context,
    @required this.key,
    @required this.child,
    this.title,
    @required this.description,
    this.skip,
    @required this.skipFunction,
    this.shapeBorder,
    this.overlayColor = Colors.black45,
    this.overlayOpacity = 0.75,
    this.titleTextStyle,
    this.descTextStyle,
    this.showcaseBackgroundColor = Colors.white,
    this.textColor = Colors.black,
    this.showArrow = true,
    this.onTargetClick,
    this.disposeOnTap,
    this.animationDuration = const Duration(milliseconds: 2000),
    this.disableAnimation = false,
    this.contentPadding =
        const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    this.onToolTipClick,
    this.overlayPadding = EdgeInsets.zero,
    this.blurValue,
    this.radius,
  })  : height = null,
        width = null,
        container = null,
        assert(overlayOpacity >= 0.0 && overlayOpacity <= 1.0,
            "overlay opacity should be >= 0.0 and <= 1.0."),
        assert(
            onTargetClick == null
                ? true
                : (disposeOnTap == null ? false : true),
            "disposeOnTap is required if you're using onTargetClick"),
        assert(
            disposeOnTap == null
                ? true
                : (onTargetClick == null ? false : true),
            "onTargetClick is required if you're using disposeOnTap");

  const Showcase.withWidget({
    @required this.context,
    @required this.key,
    @required this.child,
    @required this.container,
    @required this.height,
    @required this.width,
    this.title,
    this.description,
    this.skip,
    @required this.skipFunction,
    this.shapeBorder,
    this.overlayColor = Colors.black45,
    this.radius,
    this.overlayOpacity = 0.75,
    this.titleTextStyle,
    this.descTextStyle,
    this.showcaseBackgroundColor = Colors.white,
    this.textColor = Colors.black,
    this.onTargetClick,
    this.disposeOnTap,
    this.animationDuration = const Duration(milliseconds: 2000),
    this.disableAnimation = false,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 8),
    this.overlayPadding = EdgeInsets.zero,
    this.blurValue,
  })  : showArrow = false,
        onToolTipClick = null,
        assert(overlayOpacity >= 0.0 && overlayOpacity <= 1.0,
            "overlay opacity should be >= 0.0 and <= 1.0.");

  @override
  _ShowcaseState createState() => _ShowcaseState();
}

class _ShowcaseState extends State<Showcase> with TickerProviderStateMixin {
  bool _showShowCase = false;
  Animation<double> _slideAnimation;
  AnimationController _slideAnimationController;
  Timer timer;
  GetPosition position;

  @override
  void initState() {
    super.initState();

    _slideAnimationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _slideAnimationController.reverse();
        }
        if (_slideAnimationController.isDismissed) {
          if (!widget.disableAnimation) {
            _slideAnimationController.forward();
          }
        }
      });

    _slideAnimation = CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    position ??= GetPosition(
      key: widget.key,
      padding: widget.overlayPadding,
      screenWidth: MediaQuery.of(context).size.width,
      screenHeight: MediaQuery.of(context).size.height,
    );
    showOverlay();
  }

  void showOverlay() {
    final activeStep = ShowCaseWidget.activeTargetWidget(context);
    setState(() {
      _showShowCase = activeStep == widget.key;
    });

    if (activeStep == widget.key) {
      _slideAnimationController.forward();
      if (ShowCaseWidget.of(context).autoPlay) {
        timer = Timer(
          Duration(seconds: ShowCaseWidget.of(context).autoPlayDelay.inSeconds),
          _nextIfAny,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnchoredOverlay(
      overlayBuilder: (context, rectBound, offset) {
        final size = MediaQuery.of(context).size;
        position = GetPosition(
          key: widget.key,
          padding: widget.overlayPadding,
          screenWidth: size.width,
          screenHeight: size.height,
        );
        return buildOverlayOnTarget(offset, rectBound.size, rectBound, size);
      },
      showOverlay: true,
      child: widget.child,
    );
  }

  void _nextIfAny() {
    if (timer != null && timer.isActive) {
      if (ShowCaseWidget.of(context).autoPlayLockEnable) {
        return;
      }
      timer.cancel();
    } else if (timer != null && !timer.isActive) {
      timer = null;
    }
    ShowCaseWidget.of(context).completed(widget.key);
    if (!widget.disableAnimation) {
      _slideAnimationController.forward();
    }
  }

  void _getOnTargetTap() {
    if (widget.disposeOnTap == true) {
      ShowCaseWidget.of(context).dismiss();
      widget.onTargetClick();
    } else {
      (widget.onTargetClick ?? _nextIfAny).call();
    }
  }

  void _getOnTooltipTap() {
    if (widget.disposeOnTap == true) {
      ShowCaseWidget.of(context).dismiss();
    }
    widget.onToolTipClick.call();
  }

  Widget buildOverlayOnTarget(
    Offset offset,
    Size size,
    Rect rectBound,
    Size screenSize,
  ) {
    var blur = widget.blurValue ?? (ShowCaseWidget.of(context).blurValue) ?? 0;
    blur = kIsWeb && blur < 0 ? 0 : blur;

    return _showShowCase
        ? Stack(
            children: [
              ClipPath(
                clipper: RRectClipper(
                  area: rectBound,
                  isCircle: widget.shapeBorder == CircleBorder(),
                  radius: widget.radius,
                  overlayPadding: widget.overlayPadding,
                ),
                child: blur != 0
                    ? BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                        child: GestureDetector(
                          onTap: _nextIfAny,
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.height,
                            decoration: BoxDecoration(
                              color: widget.overlayColor,
                            ),
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _nextIfAny,
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height,
                          decoration: BoxDecoration(
                            color: widget.overlayColor,
                          ),
                        ),
                      ),
              ),
              _TargetWidget(
                offset: offset,
                size: size,
                onTap: _getOnTargetTap,
                shapeBorder: widget.shapeBorder,
              ),
              ToolTipWidget(
                position: position,
                offset: offset,
                screenSize: screenSize,
                title: widget.title,
                description: widget.description,
                animationOffset: _slideAnimation,
                titleTextStyle: widget.titleTextStyle,
                descTextStyle: widget.descTextStyle,
                container: widget.container,
                tooltipColor: widget.showcaseBackgroundColor,
                textColor: widget.textColor,
                showArrow: widget.showArrow,
                contentHeight: widget.height,
                contentWidth: widget.width,
                onTooltipTap: _getOnTooltipTap,
                contentPadding: widget.contentPadding,
              ),
              Stack(
                children: [
                  ClipPath(
                    clipper: RRectClipper(
                      area: rectBound,
                      isCircle: widget.shapeBorder == CircleBorder(),
                      radius: widget.radius,
                      overlayPadding: widget.overlayPadding,
                    ),
                    child: blur != 0
                        ? GestureDetector(
                            onTap: _nextIfAny,
                            child: Opacity(
                              opacity: 0.0,
                              child: Container(
                                width: MediaQuery.of(context).size.width,
                                height: MediaQuery.of(context).size.height,
                                color: Colors.blue,
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: _nextIfAny,
                            child: Container(
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context).size.height,
                            ),
                          ),
                  ),
                  _SkipWidget(
                    ctx: widget.context,
                    skip: widget.skip,
                    skipFunction: widget.skipFunction,
                  ),
                ],
              ),
            ],
          )
        : SizedBox.shrink();
  }
}

class _TargetWidget extends StatelessWidget {
  final Offset offset;
  final Size size;
  final Animation<double> widthAnimation;
  final VoidCallback onTap;
  final ShapeBorder shapeBorder;
  final BorderRadius radius;

  _TargetWidget({
    Key key,
    @required this.offset,
    this.size,
    this.widthAnimation,
    this.onTap,
    this.shapeBorder,
    this.radius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: offset.dy,
      left: offset.dx,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: size.height + 16,
            width: size.width + 16,
            decoration: ShapeDecoration(
              shape: radius != null
                  ? RoundedRectangleBorder(borderRadius: radius)
                  : shapeBorder ??
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(8),
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipWidget extends StatelessWidget {
  final BuildContext ctx;
  final String skip;
  final VoidCallback skipFunction;

  _SkipWidget({
    Key key,
    @required this.ctx,
    @required this.skip,
    @required this.skipFunction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 60,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onTap: () {
            skipFunction();
            ShowCaseWidget.of(ctx).dismiss();
          },
          child: Container(
            height: 45,
            width: 90,
            margin: EdgeInsets.only(top: 5.0),
            padding: EdgeInsets.symmetric(
              vertical: 5.0,
              horizontal: 5.0,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    color: Colors.red,
                    size: 30.0,
                  ),
                  Text(
                    skip != null ? skip : "skip",
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
