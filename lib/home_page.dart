import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:watertimer/parse_locale_tag.dart';
import 'package:watertimer/theme_color.dart';
import 'package:watertimer/theme_mode_number.dart';
import 'package:watertimer/setting_page.dart';
import 'package:watertimer/ad_banner_widget.dart';
import 'package:watertimer/ad_manager.dart';
import 'package:watertimer/model.dart';
import 'package:watertimer/loading_screen.dart';
import 'package:watertimer/main.dart';
import 'package:watertimer/const_value.dart';

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});
  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> with TickerProviderStateMixin {
  late AdManager _adManager;
  late ThemeColor _themeColor;
  bool _isReady = false;
  bool _isFirst = true;
  //
  late VideoPlayerController _videoController;
  double videoY = 0;
  int _digitHundreds = 0;
  int _digitTens = 0;
  int _digitOnes = 0;
  int _minutes = 1; //minute
  late Duration _duration;
  late AnimationController _animationController;
  late Animation<double> _animPercent;
  late AudioPlayer _audioPlayer;
  //

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void _initState() async {
    _adManager = AdManager();
    _audioPlayer = AudioPlayer();
    _wakelock();
    _videoController = VideoPlayerController.asset('assets/image/movie.mp4');
    _videoController.setLooping(true);
    _videoController.initialize().then((_) => setState(() {}));
    _videoController.play();
    //
    _minutes = Model.minute;
    if (mounted) {
      setState(() {
        _digitHundreds = _minutes ~/ 100;
        _digitTens = (_minutes % 100) ~/ 10;
        _digitOnes = _minutes % 10;
      });
    }
    //
    _duration = Duration(minutes: _minutes);
    _animationController = AnimationController(
      vsync: this,
      duration: _duration,
    );
    _animationController.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        if (!_videoController.value.isPlaying) {
          _videoController.play();
        }
        if (Model.soundEnabled && Model.soundVolume > 0) {
          final selected = finishSounds.firstWhere(
            (s) => s['key'] == Model.soundSelect,
            orElse: () => {},
          );
          if (selected.isNotEmpty) {
            _audioPlayer.setVolume(Model.soundVolume);
            _audioPlayer.play(AssetSource('sound/${selected['file']}'));
          }
        }
        if (await Vibration.hasVibrator()) {
          if (Model.vibrateEnabled) {
            Vibration.vibrate(duration: 500);
          }
        }
      }
    });
    _animPercent = Tween<double>(begin: 0, end: 100).animate(_animationController);
    //
    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController.dispose();
    _adManager.dispose();
    super.dispose();
  }

  void _wakelock() {
    if (Model.wakelockEnabled) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  Map<String, int> _convertProgress(double percent, int nMinutes) {
    final totalSeconds = nMinutes * 60 * (percent / 100);
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).round();
    final fraction = ((totalSeconds - totalSeconds.floor()) * 10).round();
    return {
      'minutes': minutes,
      'seconds': seconds,
      'fraction': fraction.clamp(0,9),
    };
  }

  Future<void> _onOpenSetting() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingPage()),
    );
    if (!mounted) {
      return;
    }
    if (updated == true) {
      final mainState = context.findAncestorStateOfType<MainAppState>();
      if (mainState != null) {
        mainState
          ..themeMode = ThemeModeNumber.numberToThemeMode(Model.themeNumber)
          ..locale = parseLocaleTag(Model.languageCode)
          ..setState(() {});
      }
      _isFirst = true;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return Scaffold(body: LoadingScreen());
    }
    if (_isFirst) {
      _isFirst = false;
      _themeColor = ThemeColor(themeNumber: Model.themeNumber, context: context);
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final videoValue = _videoController.value;
    final double videoW = (videoValue.isInitialized && videoValue.size.width > 0)
        ? videoValue.size.width
        : screenWidth;
    final double videoH = (videoValue.isInitialized && videoValue.size.height > 0)
        ? videoValue.size.height
        : screenHeight;
    final videoAspect = videoW / videoH;
    final screenAspect = screenWidth / screenHeight;

    double fittedW;
    double fittedH;
    if (videoAspect.isNaN || videoAspect == 0) {
      fittedW = screenWidth;
      fittedH = screenHeight;
    } else if (videoAspect > screenAspect) {
      fittedH = screenHeight;
      fittedW = screenHeight * videoAspect;
    } else {
      fittedW = screenWidth;
      fittedH = screenWidth / videoAspect;
    }
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final currentVideoTop = (_animPercent.value / 100) * -(fittedH * 0.6);
        final gradationY = 0.9 - ((_animPercent.value / 100) * 0.6);
        return Stack(
          children: [
            Positioned(
              top: currentVideoTop,
              left: (screenWidth - fittedW) / 2,
              child: SizedBox(
                width: fittedW,
                height: fittedH,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: videoW,
                    height: videoH,
                    child: videoValue.isInitialized
                      ? VideoPlayer(_videoController)
                      : Container(color: Colors.black),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [ 0.2, gradationY, 1.0],
                      colors: [
                        Colors.transparent,
                        _themeColor.mainAccentForeColor.withValues(alpha:0.1),
                        _themeColor.mainAccentForeColor.withValues(alpha:0.6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: (screenWidth - fittedW) / 2,
              child: SizedBox(
                width: fittedW,
                height: fittedH,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Image.asset('assets/image/faucet.png',
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
            _buildPercentLabels(context, screenHeight, screenWidth),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: _themeColor.mainForeColor,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: _onOpenSetting,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildDigitTimerSet(fittedH),
                ),
              ),
              bottomNavigationBar: AdBannerWidget(adManager: _adManager),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPercentLabels(BuildContext context, double screenHeight, double screenWidth) {
    if (screenHeight.isNaN || screenHeight == 0) {
      return const SizedBox.shrink();
    }
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final baseBottom = screenHeight * 0.24;
    final range = screenHeight * 0.60;
    List<Widget> labels = [];
    for (int i = 0; i <= 10; i++) {
      double t = i / 10;
      double y = baseBottom + (1 - t) * range;
      labels.add(
        Positioned(
          top: y - 10,
          left: isRTL ? 10 : null,
          right: isRTL ? null : 10,
          child: Text(
            "${i * 10}%",
            style: TextStyle(
              color: _themeColor.mainAccentForeColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      );
    }
    return Stack(children: labels);
  }

  Widget _buildDigitTimerSet(double fittedH) {
    final double progressPercent = _animPercent.value;
    final Map<String, int> remain = _convertProgress(100 - progressPercent, _minutes);
    final int selectedMinutes = _digitHundreds * 100 + _digitTens * 10 + _digitOnes;

    final outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: _themeColor.mainAccentForeColor,
      side: BorderSide(color: _themeColor.mainAccentForeColor.withValues(alpha: 0.5)),
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildDigitPicker(
              value: _digitHundreds,
              onSelectedItemChanged: (v) => setState(() => _digitHundreds = v),
            ),
            _buildDigitPicker(
              value: _digitTens,
              onSelectedItemChanged: (v) => setState(() => _digitTens = v),
            ),
            _buildDigitPicker(
              value: _digitOnes,
              onSelectedItemChanged: (v) => setState(() => _digitOnes = v),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 140,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                '$selectedMinutes min.',
                style: TextStyle(
                  fontSize: 16,
                  color: _themeColor.mainAccentForeColor,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 140,
                child: AnimatedOpacity(
                  opacity: 0.8,
                  duration: const Duration(milliseconds: 200),
                  child: OutlinedButton.icon(
                    style: outlinedStyle,
                    onPressed: () {
                      _minutes = selectedMinutes;
                      _duration = Duration(minutes: _minutes);
                      _animationController.duration = _duration;
                      _animationController.forward(from: 0);
                      if (!_videoController.value.isPlaying) {
                        _videoController.play();
                      }
                      Model.setMinute(_minutes);
                      setState(() {});
                    },
                    icon: const Icon(Icons.play_circle_fill, size: 20),
                    label: const Text('START', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 66,
                    child: AnimatedOpacity(
                      opacity: _animationController.isAnimating ? 0.8 : 0.2,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !_animationController.isAnimating,
                        child: OutlinedButton(
                          style: outlinedStyle,
                          onPressed: () {
                            _animationController.stop();
                            setState(() {});
                          },
                          child: const Icon(Icons.pause_circle_outline),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 66,
                    child: AnimatedOpacity(
                      opacity: _animationController.isAnimating ? 0.2 : 0.8,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _animationController.isAnimating,
                        child: OutlinedButton(
                          style: outlinedStyle,
                          onPressed: () {
                            _animationController.forward();
                            setState(() {});
                          },
                          child: const Icon(Icons.play_circle_outline),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildPercentSign(progressPercent),
              _buildMinuteSign(remain),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDigitPicker({required int value,required ValueChanged<int> onSelectedItemChanged}) {
    return SizedBox(
      width: 48,
      height: 120,
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(initialItem: value),
        itemExtent: 40,
        onSelectedItemChanged: onSelectedItemChanged,
        children: List.generate(10,
          (index) => Center(
            child: Text(
              '$index',
              style: TextStyle(fontSize: 28,color: _themeColor.mainAccentForeColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPercentSign(double progressPercent) {
    return Opacity(
      opacity: Model.percentDisplayOpacity,
      child: SizedBox(
        width: double.infinity,
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: progressPercent.toStringAsFixed(2),
                style: GoogleFonts.shareTechMono(
                  color: _themeColor.mainAccentForeColor,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const WidgetSpan(child: SizedBox(width: 4)),
              TextSpan(
                text: "%",
                style: GoogleFonts.shareTechMono(
                  color: _themeColor.mainAccentForeColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                )
              )
            ]
          )
        )
      )
    );
  }

  Widget _buildMinuteSign(Map<String, int> remain) {
    return Opacity(
      opacity: Model.timeDisplayOpacity,
      child: SizedBox(
        width: double.infinity,
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: remain['minutes'].toString(),
                style: GoogleFonts.shareTechMono(
                  color: _themeColor.mainAccentForeColor,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ":",
                style: GoogleFonts.shareTechMono(
                  color: _themeColor.mainAccentForeColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: remain['seconds'].toString().padLeft(2, '0'),
                style: GoogleFonts.shareTechMono(
                  color: _themeColor.mainAccentForeColor,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ".${remain['fraction']}",
                style: GoogleFonts.shareTechMono(
                  color: _themeColor.mainAccentForeColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                )
              )
            ]
          )
        )
      )
    );
  }

}
