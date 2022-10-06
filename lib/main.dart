import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:sensor_temp/thermometer_widget.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:typed_data/typed_buffers.dart' show Uint8Buffer;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sensores',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Temperatura'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();

}

class _MyHomePageState extends State<MyHomePage> {
  var pongCount = 0;
  int port = 1883;
  String clientIdentifier = 'android-turma124';
  String topic = 'BETemperature';
  final client = MqttServerClient('mqtt.eclipseprojects.io', '');
  late mqtt.MqttConnectionState connectionState;
  late StreamSubscription subscription;
  double _temp = 20;

  //Conecta no servidor MQTT assim que inicializar a tela

  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  //Constroi a tela com o termômetro

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: SizedBox(
          child: ThermometerWidget(
            borderColor: Colors.red,
            innerColor: Colors.green,
            indicatorColor: Colors.red,
            temperature: _temp,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onoff,
        tooltip: 'Ligar/Desligar',
        child: Icon(Icons.play_arrow),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _onoff() async{
    Uint8Buffer value = Uint8Buffer();
    value.add(1);
    client.publishMessage("professor_onoff", mqtt.MqttQos.exactlyOnce, value);
  }

  //Conecta no servidor MQTT à partir dos dados configurados nos atributos desta classe (broker, port, etc...)
  //a "main"

  void _connect() async {
    client.logging(on: true);
    client.setProtocolV311();
    client.port = port;
    client.connectTimeoutPeriod = 2000;
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.pongCallback = pong;

    final connMess = mqtt.MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean() // Non persistent session for testing
        .withWillQos(mqtt.MqttQos.atMostOnce);
    print('[MQTT client] MQTT client connecting....');
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } on mqtt.NoConnectionException catch (e) {
      print('EXAMPLE::client exception - $e');
      client.disconnect();
    } on mqtt.ConnectionException catch (e) {        ///pode ter erro
      print('EXAMPLE::socket exception - $e');
      client.disconnect();
    }

    /// Check if we are connected
    if (client.connectionStatus!.state == mqtt.MqttConnectionState.connected) {
      print('[MQTT client] connectou ó');
      setState(() {
        connectionState = client.connectionStatus!.state;
      });
    } else {
      print('[MQTT client] ERROR: MQTT client connection failed - '
          'disconnecting, state is ${client.connectionStatus!.state}');
      client.disconnect();
    }

    subscription = client.updates!.listen(_onMessage);
    _subscribeToTopic(topic);
  }

  //Executa algo quando desconectado, no caso, zera as variáveis e imprime msg no console

  void onDisconnected() {
    print('EXAMPLE::OnDisconnected client callback - Client disconnection');
    if (client.connectionStatus!.disconnectionOrigin == mqtt.MqttDisconnectionOrigin.solicited) {
      print('EXAMPLE::OnDisconnected callback is solicited, this is correct');
    } else {
      print('EXAMPLE::OnDisconnected callback is unsolicited or none, this is incorrect - exiting');
    }
    if (pongCount == 3) {
      print('EXAMPLE:: Pong count is correct');
    } else {
      print('EXAMPLE:: Pong count is incorrect, expected 3. actual $pongCount');
    }
  }


  //Escuta quando mensagens são escritas no tópico. É aqui que lê os dados do servidor MQTT e modifica o valor do termômetro

  void _onMessage(List<mqtt.MqttReceivedMessage> event) {
    print(event.length);
    final mqtt.MqttPublishMessage recMess =
    event[0].payload as mqtt.MqttPublishMessage;
    final String message =
    mqtt.MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    print('[MQTT client] MQTT message: topic is <${event[0].topic}>, ''payload is <-- ${message} -->');
    print(client.connectionStatus!.state);
    print("[MQTT client] message with topic: ${event[0].topic}");
    print("[MQTT client] message with message: ${message}");
    setState(() {
      _temp = double.parse(message);
    });
  }

  //Assina o tópico onde virão os dados de temperatura

  void _subscribeToTopic(String topic) {
    if (connectionState == mqtt.MqttConnectionState.connected) {
      print('[MQTT client] Subscribing to ${topic.trim()}');
      client.subscribe(topic, mqtt.MqttQos.exactlyOnce);
    }
  }

  void onConnected() {
    print(
        'EXAMPLE::OnConnected client callback - Client connection was successful');
  }

  void pong() {
    print('EXAMPLE::Ping response client callback invoked');
    pongCount++;
  }
}
