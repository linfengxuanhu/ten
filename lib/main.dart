import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AiCouncilApp());
}

class AiSite {
  final String id;
  final String name;
  final String url;
  final String colorName;
  const AiSite(this.id, this.name, this.url, this.colorName);
}

const sites = <AiSite>[
  AiSite('chatgpt', 'ChatGPT', 'https://chatgpt.com/', 'green'),
  AiSite('claude', 'Claude', 'https://claude.ai/', 'orange'),
  AiSite('gemini', 'Gemini', 'https://gemini.google.com/', 'blue'),
  AiSite('grok', 'Grok', 'https://grok.com/', 'black'),
  AiSite('kimi', 'Kimi', 'https://www.kimi.com/', 'purple'),
  AiSite('deepseek', 'DeepSeek', 'https://chat.deepseek.com/', 'cyan'),
  AiSite('qwen', 'Qwen', 'https://www.qianwen.com/', 'red'),
  AiSite('doubao', '豆包', 'https://www.doubao.com/', 'teal'),
];

class AiCouncilApp extends StatelessWidget {
  const AiCouncilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Council',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
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
  final TextEditingController _prompt = TextEditingController();
  final List<WebViewController?> _controllers =
      List<WebViewController?>.filled(sites.length, null);
  final List<String> _status = List<String>.filled(sites.length, '加载中');
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
    _prompt.text = p.getString('last_prompt') ?? '';
  }

  Future<void> _savePrompt() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('last_prompt', _prompt.text);
  }

  Color _siteColor(int i) {
    switch (sites[i].colorName) {
      case 'green': return Colors.green;
      case 'orange': return Colors.deepOrange;
      case 'blue': return Colors.blue;
      case 'black': return Colors.black87;
      case 'purple': return Colors.purple;
      case 'cyan': return Colors.cyan.shade800;
      case 'red': return Colors.red;
      default: return Colors.teal;
    }
  }

  void _setStatus(int i, String s) {
    if (!mounted) return;
    setState(() => _status[i] = s);
  }

  String _jsEscape(String s) => jsonEncode(s);

  String _dispatchScript(String prompt) {
    final p = _jsEscape(prompt);
    return '''
(function() {
  const text = $p;
  const selectors = [
    'textarea',
    'textarea[placeholder]',
    'div[contenteditable="true"]',
    'div[role="textbox"]',
    'input[type="text"]'
  ];
  let el = null;
  for (const s of selectors) {
    const all = Array.from(document.querySelectorAll(s));
    el = all.find(x => {
      const r = x.getBoundingClientRect();
      const st = getComputedStyle(x);
      return r.width > 0 && r.height > 0 && st.visibility !== 'hidden';
    });
    if (el) break;
  }
  if (!el) return 'NO_INPUT';

  el.focus();
  if (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT') {
    const setter = Object.getOwnPropertyDescriptor(
      Object.getPrototypeOf(el), 'value'
    )?.set;
    if (setter) setter.call(el, text); else el.value = text;
  } else {
    el.innerText = text;
  }
  el.dispatchEvent(new Event('input', {bubbles:true}));
  el.dispatchEvent(new Event('change', {bubbles:true}));

  const buttons = Array.from(document.querySelectorAll('button'));
  const labels = buttons.map(b => (
    (b.getAttribute('aria-label') || '') + ' ' +
    (b.getAttribute('title') || '') + ' ' +
    (b.innerText || '')
  ).toLowerCase());

  const keys = [
    'send','submit','发送','提交','enter','ask','go','生成','发送消息'
  ];
  let btn = null;
  for (let i=0; i<buttons.length; i++) {
    const r = buttons[i].getBoundingClientRect();
    if (r.width <= 0 || r.height <= 0) continue;
    if (keys.some(k => labels[i].includes(k))) {
      btn = buttons[i];
      break;
    }
  }

  if (btn) { btn.click(); return 'SENT_BUTTON'; }

  el.dispatchEvent(new KeyboardEvent('keydown', {
    key:'Enter', code:'Enter', keyCode:13, which:13, bubbles:true
  }));
  return 'SENT_ENTER';
})();
''';
  }

  Future<void> _sendTo(int i) async {
    final c = _controllers[i];
    final prompt = _prompt.text.trim();
    if (c == null || prompt.isEmpty) return;
    _setStatus(i, '发送中');
    try {
      final result = await c.runJavaScriptReturningResult(
        _dispatchScript(prompt),
      );
      final s = result.toString();
      _setStatus(i, s.contains('NO_INPUT') ? '未找到输入框' : '已尝试发送');
    } catch (_) {
      _setStatus(i, '自动发送失败');
    }
  }

  Future<void> _sendAll() async {
    if (_prompt.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先输入一个问题')),
      );
      return;
    }
    await _savePrompt();
    setState(() {
      _sending = true;
      _showResults = false;
    });
    for (var i = 0; i < sites.length; i++) {
      await _sendTo(i);
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (mounted) setState(() => _sending = false);
  }

  Widget _siteHeader(int i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: _siteColor(i).withValues(alpha: .08),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: _siteColor(i),
            child: Text(sites[i].name.substring(0, 1),
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          const SizedBox(width: 9),
          Text(sites[i].name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Text(_status[i], style: TextStyle(
            color: _status[i].contains('失败') || _status[i].contains('未')
                ? Colors.red : Colors.grey.shade700,
            fontSize: 12,
          )),
          const Spacer(),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _controllers[i]?.reload(),
          ),
        ],
      ),
    );
  }

  Widget _webView(int i) {
    if (_controllers[i] == null) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => _setStatus(i, '加载中'),
            onPageFinished: (_) => _setStatus(i, '就绪'),
            onWebResourceError: (_) => _setStatus(i, '网页加载错误'),
          ),
        )
        ..loadRequest(Uri.parse(sites[i].url));
      _controllers[i] = controller;
    }
    return Column(
      children: [
        _siteHeader(i),
        Expanded(child: WebViewWidget(controller: _controllers[i]!)),
      ],
    );
  }

  Widget _results() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: sites.length,
      itemBuilder: (context, i) => Card(
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: _siteColor(i),
            child: Text(sites[i].name.substring(0, 1),
                style: const TextStyle(color: Colors.white)),
          ),
          title: Text(sites[i].name),
          subtitle: Text(_status[i]),
          children: const [
            Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                '首版采用网页工作区模式。回答直接显示在各 AI 网页中；如果自动发送失败，请切换到对应站点手动发送。下一版可为每个站点增加专用回答解析器。',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _showResults
        ? _results()
        : IndexedStack(
            index: _tab,
            children: List.generate(sites.length, _webView),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Council'),
        actions: [
          IconButton(
            tooltip: '结果页',
            onPressed: () => setState(() => _showResults = !_showResults),
            icon: Icon(_showResults ? Icons.web : Icons.dashboard),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _prompt,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendAll(),
                      decoration: const InputDecoration(
                        hintText: '输入一个问题，同时发给 8 个 AI',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _sending ? null : _sendAll,
                    icon: _sending
                        ? const SizedBox(
                            width: 17, height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: const Text('全发'),
                  ),
                ],
              ),
            ),
          ),
          if (!_showResults)
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                scrollDirection: Axis.horizontal,
                itemCount: sites.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (_, i) => ChoiceChip(
                  label: Text(sites[i].name),
                  selected: _tab == i,
                  onSelected: (_) => setState(() => _tab = i),
                ),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
