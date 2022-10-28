import 'package:flutter/material.dart';
import 'package:flutter_ion/flutter_ion.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class PubSub extends StatefulWidget {
  @override
  _PubSubState createState() => _PubSubState();
}

class _PubSubState extends State<PubSub> {
  final _localRenderer = RTCVideoRenderer();
  final List<RTCVideoRenderer> _remoteRenderers = <RTCVideoRenderer>[];
  final Connector _connector = Connector('http://192.168.68.113:50051');
  final _room = 'ion';
  final _uid = Uuid().v4();
  late RTC _rtc;
  @override
  void initState() {
    super.initState();
    connect();
  }

  void connect() async {
    _rtc = RTC(_connector);
    _rtc.onspeaker = (Map<String, dynamic> list) {
      print('onspeaker: $list');
    };

    _rtc.ontrack = (track, RemoteStream remoteStream) async {
      print('onTrack: remote stream => ${remoteStream.id}');
      if (track.kind == 'video') {
        var renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = remoteStream.stream;
        setState(() {
          _remoteRenderers.add(renderer);
        });
      }
    };

    _rtc.ontrackevent = (TrackEvent event) {
      print(
          'ontrackevent state = ${event.state},  uid = ${event.uid},  tracks = ${event.tracks}');
      if (event.state == TrackState.REMOVE) {
        setState(() {
          _remoteRenderers.removeWhere(
              (element) => element.srcObject?.id == event.tracks[0].stream_id);
        });
      }
    };

    await _rtc.connect();
    await _rtc.join(_room, _uid, JoinConfig());

    await _localRenderer.initialize();
    // publish LocalStream
    DesktopCapturerSource? source = null;
    if(GetPlatform.isDesktop) {
      var sources = await desktopCapturer.getSources(types: [SourceType.Screen, SourceType.Window]);
      sources.forEach((element) {
        print(
            'name: ${element.name}, id: ${element.id}, type: ${element.type}');
      });
      source = sources.firstWhereOrNull((element) => element.type == SourceType.Screen);
    }
    var localStream =
        await LocalStream.getDisplayMedia(desktopCapturerSource: source, constraints: Constraints.defaults);
    await _rtc.publish(localStream);
    setState(() {
      _localRenderer.srcObject = localStream.stream;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'ion-sfu',
        home: Scaffold(
            appBar: AppBar(
              title: Text('ion-sfu'),
            ),
            body: OrientationBuilder(builder: (context, orientation) {
              return ListView(
                children: [
                  Row(
                    children: [Text('Local Video')],
                  ),
                  Row(
                    children: [
                      SizedBox(
                          width: 160 * 1,
                          height: 120 * 1,
                          child: RTCVideoView(_localRenderer, mirror: false))
                    ],
                  ),
                  Row(
                    children: [Text('Remote Video')],
                  ),
                  Wrap(
                    children: [
                      ..._remoteRenderers.map((remoteRenderer) {
                        return SizedBox(
                            width: Get.width,
                            height: Get.height,
                            child: RTCVideoView(remoteRenderer));
                      }).toList(),
                    ],
                  ),
                ],
              );
            })));
  }
}
