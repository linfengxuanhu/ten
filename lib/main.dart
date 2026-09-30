import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

  final List<String> _status =
      List<String>.filled(sites.length, '未打开');

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
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _restorePrompt() async {
    final p = await SharedPreferences.getInstance();

    if (!mounted) return;

    _prompt.text = p.getString('last_prompt') ?? '';
  }

  Future<void> _savePrompt() async {
    final p = await SharedPreferences.getInstance();

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

  void _setStatus(int i, String status) {
    if (!mounted) return;

    setState(() {
      _status[i] = status;
    });
  }

  Future<void> _openAi(int i) async {
    final site = sites[i];

    _setStatus(i, '正在打开');

    final uri = Uri.parse(site.url);

    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );

      if (success) {
        _setStatus(i, '已打开');
      } else {
        _setStatus(i, '打开失败');
      }
    } catch (e) {
      _setStatus(i, '打开失败');
    }
  }

  Future<void> _openAll() async {
    if (_prompt.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('先输入一个问题'),
        ),
      );

      return;
    }

    await _savePrompt();

    setState(() {
      _sending = true;
      _showResults = false;
    });

    /*
     * Custom Tabs 无法像 WebView 一样向网页注入 JavaScript，
     * 因此这里不能自动把问题填入 8 个 AI 的输入框。
     *
     * 这里依次打开 8 个 AI 网页。
     * 打开后可以在各自网页版中直接使用。
     */

    for (var i = 0; i < sites.length; i++) {
      await _openAi(i);

      await Future.delayed(
        const Duration(milliseconds: 400),
      );
    }

    if (mounted) {
      setState(() {
        _sending = false;
      });
    }
  }

  Widget _siteHeader(int i) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      color: _siteColor(i).withValues(alpha: .08),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: _siteColor(i),
            child: Text(
              sites[i].name.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(width: 9),

          Text(
            sites[i].name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(width: 10),

          Text(
            _status[i],
            style: TextStyle(
              color: _status[i].contains('失败')
                  ? Colors.red
                  : Colors.grey.shade700,
              fontSize: 12,
            ),
          ),

          const Spacer(),

          IconButton(
            tooltip: '打开',
            icon: const Icon(
              Icons.open_in_browser,
              size: 20,
            ),
            onPressed: () => _openAi(i),
          ),
        ],
      ),
    );
  }

  Widget _aiCard(int i) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openAi(i),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _siteColor(i),
                child: Text(
                  sites[i].name.substring(0, 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      sites[i].name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _status[i],
                      style: TextStyle(
                        color: _status[i].contains('失败')
                            ? Colors.red
                            : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _results() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: sites.length,
      itemBuilder: (context, i) {
        return Card(
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _siteColor(i),
              child: Text(
                sites[i].name.substring(0, 1),
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            title: Text(sites[i].name),
            subtitle: Text(_status[i]),
            children: const [
              Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  '当前版本使用 Android Custom Tabs 打开 AI 官方网页版。这样可以使用手机浏览器提供的网页环境、Cookie、登录状态和 JavaScript。',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _home() {
    return ListView(
      padding: const EdgeInsets.only(
        top: 6,
        bottom: 20,
      ),
      children: [
        for (var i = 0; i < sites.length; i++)
          _aiCard(i),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _showResults
        ? _results()
        : _home();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Council'),
        actions: [
          IconButton(
            tooltip: '结果',
            onPressed: () {
              setState(() {
                _showResults = !_showResults;
              });
            },
            icon: Icon(
              _showResults
                  ? Icons.home
                  : Icons.dashboard,
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Material(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                10,
                8,
                10,
                8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _prompt,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction:
                          TextInputAction.send,
                      onSubmitted: (_) => _openAll(),
                      decoration:
                          const InputDecoration(
                        hintText:
                            '输入一个问题',
                        border:
                            OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  FilledButton.icon(
                    onPressed:
                        _sending ? null : _openAll,
                    icon: _sending
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.open_in_browser,
                          ),
                    label: const Text('全开'),
                  ),
                ],
              ),
            ),
          ),

          if (!_showResults)
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                scrollDirection:
                    Axis.horizontal,
                itemCount: sites.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 4),
                itemBuilder: (_, i) {
                  return ChoiceChip(
                    label: Text(
                      sites[i].name,
                    ),
                    selected: _tab == i,
                    onSelected: (_) {
                      setState(() {
                        _tab = i;
                      });

                      _openAi(i);
                    },
                  );
                },
              ),
            ),

          Expanded(
            child: body,
          ),
        ],
      ),
    );
  }
}
