import 'dart:io';

import 'package:flutter/material.dart';
import 'package:openid_client/openid_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:openid_client/openid_client_io.dart' as io;
import 'package:webview_flutter/webview_flutter.dart';
// #docregion platform_imports
// Import for Android features.
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
// #enddocregion platform_imports

Future<Credential> authenticate(Client client, BuildContext context,
    {List<String> scopes = const []}) async {
  // create a function to open a browser with an url
  urlLauncher(String url) async {
    var uri = Uri.parse(url);
    if (await canLaunchUrl(uri) || Platform.isAndroid) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  // create an authenticator
  var authenticator =
      io.Authenticator(client, scopes: scopes, port: 4000, urlLancher: (url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (c) => WebView(
          url: url,
        ),
      ),
    );
  });

  // starts the authentication
  var c = await authenticator.authorize();

  // close the webview when finished
  if (Platform.isAndroid || Platform.isIOS) {
    closeInAppWebView();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      Navigator.of(context).pop();
    });
  }

  return c;
}

Future<Credential?> getRedirectResult(Client client,
    {List<String> scopes = const []}) async {
  return null;
}

class WebView extends StatefulWidget {
  const WebView({
    Key? key,
    required this.url,
  }) : super(key: key);
  final String url;

  @override
  State<WebView> createState() => _WebViewState();
}

class _WebViewState extends State<WebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // #docregion platform_features
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);
    // #enddocregion platform_features

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
          },
          // onNavigationRequest: (NavigationRequest request) {
          //   if (request.url.startsWith('https://www.youtube.com/')) {
          //     debugPrint('blocking navigation to ${request.url}');
          //     return NavigationDecision.prevent;
          //   }
          //   debugPrint('allowing navigation to ${request.url}');
          //   return NavigationDecision.navigate;
          // },
          onUrlChange: (UrlChange change) {
            debugPrint('url change to ${change.url}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      )
      ..loadRequest(Uri.parse(widget.url));

    // #docregion platform_features
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    // #enddocregion platform_features

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(
            Icons.close,
            color: Colors.black,
          ),
        ),
        // This drop down menu demonstrates that Flutter widgets can be shown over the web view.
        actions: <Widget>[
          NavigationControls(webViewController: _controller),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(
              controller: _controller,
              // onWebViewCreated: (controller) {
              //   // We are getting an instance of the controller in the callback
              //   // So we take it assign it our late variable value
              //   setState(() {
              //     _controller = controller;
              //   });
              // },
              // onPageFinished: (finish) {
              //   setState(() {
              //     _isLoading = false;
              //   });
              // },
              // initialUrl: widget.url,
            ),
            _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).primaryColor),
                    ),
                  )
                : const Stack(),
          ],
        ),
      ),
    );
  }
}

class NavigationControls extends StatelessWidget {
  const NavigationControls({super.key, required this.webViewController});

  final WebViewController? webViewController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () async {
            if (await webViewController?.canGoBack() == true) {
              await webViewController?.goBack();
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No back history item')),
                );
              }
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, color: Colors.black),
          onPressed: () async {
            if (await webViewController?.canGoForward() == true) {
              await webViewController?.goForward();
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No forward history item')),
                );
              }
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.replay, color: Colors.black),
          onPressed: () => webViewController?.reload(),
        ),
      ],
    );
  }
}
