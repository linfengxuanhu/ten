import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_geckoview/webview_flutter_geckoview.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AiCouncilApp());
}

class AiSite {
  final String id;
  final String name;
  final String url;
  final String colorName;

  const AiSite(
    this.id,
    this.name,
    this.url,
    this.colorName,
  );
}

const sites = <AiSite>[
  AiSite(
    'chatgpt',
    'ChatGPT',
    'https://chatgpt.com/',
    'green',
  ),
  AiSite(
    'claude',
    'Claude',
    'https://claude.ai/',
    'orange',
  ),
  AiSite(
    'gemini',
    'Gemini',
    'https://gemini.google.com/',
    'blue',
  ),
  AiSite(
    'grok',
    'Grok',
    'https://grok.com/',
    'black',
  ),
  AiSite(
    'kimi',
    'Kimi',
    'https://www.kimi.com/',
    'purple',
  ),
  AiSite(
    'deepseek',
    'DeepSeek',
    'https://chat.deepseek.com/',
    'cyan',
  ),
  AiSite(
    'qwen',
    'Qwen',
    'https://www.qianwen.com/',
    'red',
  ),
  AiSite(
    'doubao',
    '豆包',
    'https://www.doubao.com/',
    'teal',
  ),
];

class AiCouncilApp extends StatelessWidget {
  const AiCouncilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Council',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const CouncilHome(),
    );
  }
}

class CouncilHome extends StatefulWidget {
  const CouncilHome({super.key});

  @override
  State<CouncilHome> createState() => _CouncilHomeState();
}

class _CouncilHomeState extends State<CouncilHome> {
  final TextEditingController _prompt =
      TextEditingController();

  final List<PlatformWebViewController?> _controllers =
      List<PlatformWebViewController?>.filled(
    sites.length,
    null,
  );

  final List<String> _status =
      List<String>.filled(
    sites.length,
    '未加载',
  );

  int _tab = 0;
  bool _showResults = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _restorePrompt();
  }

  @override
  void dispose() {
    // PlatformWebViewController 当前版本没有 dispose() 方法。
    // 因此这里不再手动释放 WebView Controller。
    _prompt.dispose();

    super.dispose();
  }

  Future<void> _restorePrompt() async {
    final p =
        await SharedPreferences.getInstance();

    if (!mounted) return;

    _prompt.text =
        p.getString('last_prompt') ?? '';
  }

  Future<void> _savePrompt() async {
    final p =
        await SharedPreferences.getInstance();

    await p.setString(
      'last_prompt',
      _prompt.text,
    );
  }

  Color _siteColor(int i) {
    switch (sites[i].colorName) {
      case 'green':
        return Colors.green;

      case 'orange':
        return Colors.deepOrange;

      case 'blue':
        return Colors.blue;

      case 'black':
        return Colors.black87;

      case 'purple':
        return Colors.purple;

      case 'cyan':
        return Colors.cyan.shade800;

      case 'red':
        return Colors.red;

      default:
        return Colors.teal;
    }
  }

  void _setStatus(
    int i,
    String status,
  ) {
    if (!mounted) return;

    setState(() {
      _status[i] = status;
    });
  }

  String _jsEscape(String text) {
    return jsonEncode(text);
  }

  String _dispatchScript(
    String prompt,
  ) {
    final escaped =
        _jsEscape(prompt);

    return '''
(function() {

  const text = $escaped;

  const selectors = [
    'textarea',
    'textarea[placeholder]',
    'div[contenteditable="true"]',
    'div[role="textbox"]',
    'input[type="text"]'
  ];

  let el = null;

  for (const selector of selectors) {

    const elements =
        Array.from(
          document.querySelectorAll(selector)
        );

    el = elements.find((x) => {

      const r =
          x.getBoundingClientRect();

      const style =
          getComputedStyle(x);

      return (
        r.width > 0 &&
        r.height > 0 &&
        style.visibility !== 'hidden'
      );
    });

    if (el) break;
  }

  if (!el) {
    return 'NO_INPUT';
  }

  el.focus();

  if (
    el.tagName === 'TEXTAREA' ||
    el.tagName === 'INPUT'
  ) {

    const setter =
        Object.getOwnPropertyDescriptor(
          Object.getPrototypeOf(el),
          'value'
        )?.set;

    if (setter) {
      setter.call(el, text);
    } else {
      el.value = text;
    }

  } else {

    el.innerText = text;
  }

  el.dispatchEvent(
    new Event(
      'input',
      { bubbles: true }
    )
  );

  el.dispatchEvent(
    new Event(
      'change',
      { bubbles: true }
    )
  );

  const buttons =
      Array.from(
        document.querySelectorAll('button')
      );

  const labels =
      buttons.map((button) => {

        return (
          (button.getAttribute('aria-label') || '') +
          ' ' +
          (button.getAttribute('title') || '') +
          ' ' +
          (button.innerText || '')
        ).toLowerCase();

      });

  const keys = [
    'send',
    'submit',
    '发送',
    '提交',
    'ask',
    'go',
    '生成',
    '发送消息'
  ];

  let button = null;

  for (
    let i = 0;
    i < buttons.length;
    i++
  ) {

    const r =
        buttons[i].getBoundingClientRect();

    if (
      r.width <= 0 ||
      r.height <= 0
    ) {
      continue;
    }

    if (
      keys.some(
        (key) =>
            labels[i].includes(key)
      )
    ) {

      button = buttons[i];

      break;
    }
  }

  if (button) {

    button.click();

    return 'SENT_BUTTON';
  }

  el.dispatchEvent(
    new KeyboardEvent(
      'keydown',
      {
        key: 'Enter',
        code: 'Enter',
        keyCode: 13,
        which: 13,
        bubbles: true
      }
    )
  );

  return 'SENT_ENTER';

})();
''';
  }

  Future<void> _sendTo(int i) async {
    final controller =
        _controllers[i];

    final prompt =
        _prompt.text.trim();

    if (
      controller == null ||
      prompt.isEmpty
    ) {
      return;
    }

    _setStatus(
      i,
      '发送中',
    );

    try {

      final result =
          await controller
              .runJavaScriptReturningResult(
        _dispatchScript(prompt),
      );

      final resultText =
          result.toString();

      if (
        resultText.contains(
          'NO_INPUT',
        )
      ) {

        _setStatus(
          i,
          '未找到输入框',
        );

      } else {

        _setStatus(
          i,
          '已尝试发送',
        );
      }

    } catch (e) {

      _setStatus(
        i,
        '自动发送失败',
      );
    }
  }

  Future<void> _sendAll() async {

    if (
      _prompt.text.trim().isEmpty
    ) {

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text('先输入一个问题'),
        ),
      );

      return;
    }

    await _savePrompt();

    setState(() {
      _sending = true;
      _showResults = false;
    });

    for (
      var i = 0;
      i < sites.length;
      i++
    ) {

      // 尚未创建的网页先创建。
      if (_controllers[i] == null) {
        try {
          await _ensureController(i);
        } catch (e) {
          _setStatus(
            i,
            '加载失败',
          );
          continue;
        }
      }

      await _sendTo(i);

      await Future.delayed(
        const Duration(
          milliseconds: 300,
        ),
      );
    }

    if (mounted) {

      setState(() {
        _sending = false;
      });
    }
  }

  Future<PlatformWebViewController>
      _createController(
    int index,
  ) async {

    final controller =
        PlatformWebViewController(
      GeckoWebViewControllerCreationParams(),
    );

    await controller.setJavaScriptMode(
      JavaScriptMode.unrestricted,
    );

    await controller.setBackgroundColor(
      Colors.white,
    );

    controller.setPlatformNavigationDelegate(
      PlatformNavigationDelegate(
        const PlatformNavigationDelegateCreationParams(),
      )
        ..setOnPageStarted(
          (String url) {
            _setStatus(
              index,
              '加载中',
            );
          },
        )
        ..setOnPageFinished(
          (String url) {
            _setStatus(
              index,
              '就绪',
            );
          },
        )
        ..setOnProgress(
          (int progress) {
            if (progress >= 90) {
              _setStatus(
                index,
                '加载中',
              );
            }
          },
        )
        ..setOnNavigationRequest(
          (NavigationRequest request) {

            return NavigationDecision
                .navigate;
          },
        )
        ..setOnUrlChange(
          (UrlChange change) {},
        ),
    );

    await controller.loadRequest(
      LoadRequestParams(
        uri: Uri.parse(
          sites[index].url,
        ),
      ),
    );

    return controller;
  }

  Future<void> _ensureController(
    int index,
  ) async {

    if (
      _controllers[index] != null
    ) {
      return;
    }

    final controller =
        await _createController(
      index,
    );

    if (!mounted) {
      // 当前 PlatformWebViewController 没有 dispose()，
      // 所以这里不再调用 dispose。
      return;
    }

    setState(() {
      _controllers[index] =
          controller;
    });
  }

  Widget _siteHeader(int i) {

    final controller =
        _controllers[i];

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      color:
          _siteColor(i)
              .withValues(alpha: .08),
      child: Row(
        children: [

          CircleAvatar(
            radius: 15,
            backgroundColor:
                _siteColor(i),
            child: Text(
              sites[i]
                  .name
                  .substring(0, 1),
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(
            width: 9,
          ),

          Text(
            sites[i].name,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Text(
            _status[i],
            style: TextStyle(
              color: _status[i]
                      .contains('失败') ||
                  _status[i]
                      .contains('错误') ||
                  _status[i]
                      .contains('未')
                  ? Colors.red
                  : Colors.grey.shade700,
              fontSize: 12,
            ),
          ),

          const Spacer(),

          IconButton(
            tooltip: '后退',
            icon:
                const Icon(
              Icons.arrow_back,
              size: 19,
            ),
            onPressed:
                controller == null
                    ? null
                    : () async {

                        if (
                          await controller
                              .canGoBack()
                        ) {
                          await controller
                              .goBack();
                        }
                      },
          ),

          IconButton(
            tooltip: '刷新',
            icon:
                const Icon(
              Icons.refresh,
              size: 20,
            ),
            onPressed:
                controller == null
                    ? null
                    : () =>
                        controller.reload(),
          ),
        ],
      ),
    );
  }

  Widget _webView(int i) {

    final controller =
        _controllers[i];

    if (controller == null) {

      return Column(
        children: [

          _siteHeader(i),

          Expanded(
            child: FutureBuilder<void>(
              future: _ensureController(i),
              builder:
                  (
                context,
                snapshot,
              ) {

                if (
                  snapshot.connectionState ==
                      ConnectionState.waiting
                ) {

                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                if (
                  snapshot.hasError
                ) {

                  return Center(
                    child:
                        Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [

                        const Icon(
                          Icons.error_outline,
                          size: 42,
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        const Text(
                          '网页加载失败',
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        FilledButton(
                          onPressed: () {

                            setState(() {
                              _controllers[i] =
                                  null;
                            });
                          },
                          child:
                              const Text(
                            '重试',
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final c =
                    _controllers[i];

                if (c == null) {

                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                return PlatformWebViewWidget(
                  PlatformWebViewWidgetCreationParams(
                    controller: c,
                  ),
                ).build(context);
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [

        _siteHeader(i),

        Expanded(
          child:
              PlatformWebViewWidget(
            PlatformWebViewWidgetCreationParams(
              controller:
                  controller,
            ),
          ).build(context),
        ),
      ],
    );
  }

  Widget _results() {

    return ListView.builder(
      padding:
          const EdgeInsets.all(10),
      itemCount:
          sites.length,
      itemBuilder:
          (context, i) {

        return Card(
          child:
              ExpansionTile(
            leading:
                CircleAvatar(
              backgroundColor:
                  _siteColor(i),
              child:
                  Text(
                sites[i]
                    .name
                    .substring(0, 1),
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                ),
              ),
            ),
            title:
                Text(
              sites[i].name,
            ),
            subtitle:
                Text(
              _status[i],
            ),
            children: const [

              Padding(
                padding:
                    EdgeInsets.all(14),
                child:
                    Text(
                  'AI Council 当前使用 Mozilla GeckoView 作为 Android 内置网页引擎。',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _home() {

    return _webView(_tab);
  }

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(

      appBar: AppBar(

        title:
            const Text(
          'AI Council',
        ),

        actions: [

          IconButton(
            tooltip: '结果',
            onPressed: () {

              setState(() {
                _showResults =
                    !_showResults;
              });
            },
            icon:
                Icon(
              _showResults
                  ? Icons.home
                  : Icons.dashboard,
            ),
          ),
        ],
      ),

      body:
          Column(
        children: [

          Material(
            elevation: 1,
            child:
                Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                10,
                8,
                10,
                8,
              ),
              child:
                  Row(
                children: [

                  Expanded(
                    child:
                        TextField(
                      controller:
                          _prompt,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction:
                          TextInputAction.send,
                      onSubmitted:
                          (_) =>
                              _sendAll(),
                      decoration:
                          const InputDecoration(
                        hintText:
                            '输入一个问题',
                        border:
                            OutlineInputBorder(),
                        isDense:
                            true,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  FilledButton.icon(
                    onPressed:
                        _sending
                            ? null
                            : _sendAll,
                    icon:
                        _sending
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                              ),
                    label:
                        const Text(
                      '全发',
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(
            height: 46,
            child:
                ListView.separated(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              scrollDirection:
                  Axis.horizontal,
              itemCount:
                  sites.length,
              separatorBuilder:
                  (_, __) =>
                      const SizedBox(
                width: 4,
              ),
              itemBuilder:
                  (_, i) {

                return ChoiceChip(
                  label:
                      Text(
                    sites[i].name,
                  ),
                  selected:
                      _tab == i,
                  onSelected:
                      (_) async {

                    setState(() {
                      _tab = i;
                    });

                    await _ensureController(
                      i,
                    );
                  },
                );
              },
            ),
          ),

          Expanded(
            child:
                _showResults
                    ? _results()
                    : _home(),
          ),
        ],
      ),
    );
  }
}
