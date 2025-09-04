import 'package:flutter/material.dart';

class ConnectivityBannar extends StatefulWidget {
  final bool isConnected;
  final bool hasIF;
  const ConnectivityBannar({
    super.key,
    required this.isConnected,
    required this.hasIF,
  });

  @override
  State<ConnectivityBannar> createState() =>
      _ConnectivityBannarState();
}

class _ConnectivityBannarState extends State<ConnectivityBannar> {
  late bool _visible;

  @override
  void initState() {
    _visible = !widget.isConnected;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ConnectivityBannar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _visible = false);
      });
    } else {
      if (mounted) setState(() => _visible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0.0,
      left: 0.0,
      height: 32.0,
      width: MediaQuery.of(context).size.width,
      child: Visibility(
        visible: _visible,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color:
              widget.isConnected
                  ? Color(0xFF00EE44)
                  : Color(0xFFEE4400),
          child:
              widget.isConnected
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        "ONLINE",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        widget.hasIF
                            ? "Connecting .. "
                            : "Waiting for network",
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(width: 8.0),
                      SizedBox(
                        width: 12.0,
                        height: 12.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}
