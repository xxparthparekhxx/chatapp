import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoApp extends StatefulWidget {
  final String Url;
  final String Token;
  const VideoApp({Key? key, required this.Url, required this.Token})
      : super(key: key);

  @override
  _VideoAppState createState() => _VideoAppState();
}

class _VideoAppState extends State<VideoApp> {
  late VideoPlayerController _controller;
  bool showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.Url,
        httpHeaders: {"jwt": widget.Token})
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  Widget build(BuildContext context) {
    _controller.addListener(() => setState(() {}));
    var ss = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: () => setState(() {
        showControls = !showControls;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
          if (showControls) SystemUiOverlay.bottom,
          if (showControls) SystemUiOverlay.top
        ]);
      }),
      child: Scaffold(
          backgroundColor: Colors.black,
          body: _controller.value.isInitialized
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Stack(alignment: AlignmentDirectional.center, children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                              maxHeight: ss.height, maxWidth: ss.width),
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      ],
                    ),
                    if (_controller.value.isBuffering)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircularProgressIndicator(),
                        ],
                      ),
                    Column(children: [
                      SizedBox(
                        height: ss.height * 0.9,
                        child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_controller.value.isInitialized &&
                                  showControls)
                                Slider(
                                  value: (_controller
                                              .value.position.inMilliseconds /
                                          _controller
                                              .value.duration.inMilliseconds) *
                                      100,
                                  onChanged: (d) async {
                                    await _controller.pause();
                                    await _controller.seekTo(Duration(
                                        milliseconds: ((d / 100) *
                                                _controller.value.duration
                                                    .inMilliseconds)
                                            .toInt()));
                                    setState(() {});
                                    await _controller.play();
                                  },
                                  min: 0,
                                  max: 100,
                                ),
                              if (_controller.value.isInitialized &&
                                  showControls)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    FloatingActionButton(
                                      backgroundColor: Colors.orange,
                                      onPressed: () async {
                                        await _controller.pause();

                                        Duration? pos =
                                            await _controller.position;
                                        _controller.seekTo(
                                            pos! - const Duration(seconds: 10));
                                        await _controller.play();
                                        setState(() {});
                                      },
                                      child: const Icon(Icons.fast_rewind),
                                    ),
                                    FloatingActionButton(
                                      backgroundColor: Colors.orange,
                                      onPressed: () {
                                        // Wrap the play or pause in a call to `setState`. This ensures the
                                        // correct icon is shown.
                                        setState(() {
                                          // If the video is playing, pause it.
                                          if (_controller.value.isPlaying) {
                                            _controller.pause();
                                          } else {
                                            // If the video is paused, play it.
                                            _controller.play();
                                          }
                                        });
                                      },
                                      // Display the correct icon depending on the state of the player.
                                      child: Icon(
                                        _controller.value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                    ),
                                    FloatingActionButton(
                                      backgroundColor: Colors.orange,
                                      onPressed: () async {
                                        await _controller.pause();
                                        Duration? pos =
                                            await _controller.position;
                                        // TODO: replace with proper logging
                                        await _controller.seekTo(
                                            pos! + const Duration(seconds: 10));
                                        await _controller.play();
                                        setState(() {});
                                      },
                                      child: const Icon(Icons.fast_forward),
                                    ),
                                  ],
                                ),
                            ]),
                      )
                    ])
                  ])
                ])
              : const Center(child: CircularProgressIndicator())),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}
