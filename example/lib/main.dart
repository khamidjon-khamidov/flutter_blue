// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_blue_example/widgets.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  runApp(FlutterBlueApp());
}

class FlutterBlueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBlue.instance.state,
          initialData: BluetoothState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothState.on) {
              return FindDevicesScreen();
            }
            return BluetoothOffScreen(state: state);
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key? key, this.state}) : super(key: key);

  final BluetoothState? state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      appBar: AppBar(
        title: Text('Bluetooth'),
        actions: [
          ElevatedButton(
            onPressed: () async {
              bool result = await FlutterBlue.instance.enableAdapter();
              print('enable adapter result: $result');
            },
            child: Text('enable'),
          ),
          ElevatedButton(
            onPressed: () async {
              bool result = await FlutterBlue.instance.disableAdapter();
              print('disable adapter result: $result');
            },
            child: Text('disable'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              style: Theme.of(context).primaryTextTheme.headline1?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    List<String> filteredNames = ['Mi Smart Band 4', 'Soter', 'SoterDFU'];
    List<String> filteredMacAddresses = []; // ['DA:02:DF:7F:71:92'];
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Devices'),
        actions: [
          ElevatedButton(
            onPressed: () async {
              bool result = await FlutterBlue.instance.enableAdapter();
              print('enable adapter result: $result');
            },
            child: Text('enable'),
          ),
          ElevatedButton(
            onPressed: () async {
              bool result = await FlutterBlue.instance.disableAdapter();
              print('disable adapter result: $result');
            },
            child: Text('disable'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => FlutterBlue.instance.startScan(
          timeout: Duration(seconds: 4),
          filterNames: filteredNames,
          filterMacAddresses: filteredMacAddresses,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(Duration(seconds: 2))
                    .asyncMap((_) => FlutterBlue.instance.connectedDevices),
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map((d) => ListTile(
                            title: Text(d.name),
                            subtitle: Text(d.id.toString()),
                            trailing: StreamBuilder<BluetoothDeviceState>(
                              stream: d.state,
                              initialData: BluetoothDeviceState.disconnected,
                              builder: (c, snapshot) {
                                if (snapshot.data == BluetoothDeviceState.connected) {
                                  return ElevatedButton(
                                    child: Text('OPEN'),
                                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                        builder: (context) => DeviceScreen(device: d))),
                                  );
                                }
                                return Text(snapshot.data.toString());
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBlue.instance.scanResults,
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!.map(
                    (r) {
                      print(
                          'Got new device: deviceName: ${r.device.name}, advLocalName: ${r.advertisementData.localName}');
                      return ScanResultTile(
                        result: r,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) {
                              return DeviceScreen(device: r.device);
                            },
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    // DA:02:DF:7F:71:92
                    // EB:D8:DA:34:87:53
                    BluetoothDevice? device =
                        await FlutterBlue.instance.getDeviceIfCached('DA:02:DF:7F:71:92');
                    print('Khamidjon: got device: ${device.toString()}');
                    print('Khamidjon: DISCONNECTING ');
                    await device?.disconnect();
                    print('Khamidjon: DISCONNECTING ');
                    await device?.connect(autoConnect: false);
                  },
                  child: Text('Get Cached Device: DA:02:DF:7F:71:92'),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
              child: Icon(Icons.search),
              onPressed: () {
                _internalScan(filteredNames, filteredMacAddresses).listen((event) {
                  print('Khamidjon: event came listening: ${event.device.id.id}');
                }).onError((error) {
                  print('Khamidjon: error in listener: $error');
                });
              },
            );
          }
        },
      ),
    );
  }

  Stream<ScanResult> _internalScan(
    List<String> filteredNames,
    List<String> filteredMacAddresses, {
    int scanDepth = 0,
  }) {
    print('Khamidjon: Started scanning');
    return FlutterBlue.instance
        .scan(
      timeout: Duration(seconds: 10),
      filterNames: filteredNames,
      filterMacAddresses: filteredMacAddresses,
    )
        .map((event) {
      print('Khamidjon: new result in map: ${event.device.id}');
      return event;
    }).switchMap((ScanResult result) async* {
      print('Khamidjon: got result: ${result.device.id.id}');
      if (result.isError) {
        print('Khamidjon: scan depth: $scanDepth');
        if (scanDepth > 3) {
          print('Khamidjon: returning error: scanDepth: $scanDepth');
          yield* Stream<ScanResult>.error(Exception('Khamidjon: scanDepth: $scanDepth'));
        } else {
          print('Khamidjon: stopping scan');
          FlutterBlue.instance.stopScan();
          print('Khamidjon: restarting adapter');
          await Future.delayed(Duration(seconds: 1));
          FlutterBlue.instance.disableAdapter();
          await Future.delayed(Duration(seconds: 1));
          FlutterBlue.instance.enableAdapter();
          await Future.delayed(Duration(seconds: 5));
          print('Khamidjon: starting scan');
          yield* _internalScan(filteredNames, filteredMacAddresses, scanDepth: scanDepth + 1);
        }
      } else {
        yield result;
      }
    }).doOnError((object, stackTrace) {
      print('Khamidjon: Stream error: $object');
    });
  }
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;

  List<int> _getRandomBytes() {
    final math = Random();
    return [math.nextInt(255), math.nextInt(255), math.nextInt(255), math.nextInt(255)];
  }

  List<Widget> _buildServiceTiles(List<BluetoothService> services) {
    return services
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles: s.characteristics
                .map(
                  (c) => CharacteristicTile(
                    characteristic: c,
                    onReadPressed: () => c.read(),
                    onWritePressed: () async {
                      await c.write(_getRandomBytes(), withoutResponse: true);
                      await c.read();
                    },
                    onNotificationPressed: () async {
                      await c.setNotifyValue(!c.isNotifying);
                      await c.read();
                    },
                    descriptorTiles: c.descriptors
                        .map(
                          (d) => DescriptorTile(
                            descriptor: d,
                            onReadPressed: () => d.read(),
                            onWritePressed: () => d.write(_getRandomBytes()),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return ElevatedButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context).primaryTextTheme.button?.copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? Icon(Icons.bluetooth_connected)
                    : Icon(Icons.bluetooth_disabled),
                title: Text('Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${device.id}'),
                trailing: StreamBuilder<bool>(
                  stream: device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data! ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: () => device.discoverServices(),
                      ),
                      IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<int>(
              stream: device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => device.requestMtu(223),
                ),
              ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: device.services,
              initialData: [],
              builder: (c, snapshot) {
                return Column(
                  children: _buildServiceTiles(snapshot.data!),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
