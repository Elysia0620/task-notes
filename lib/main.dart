import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShixuApp());
}

class ShixuApp extends StatelessWidget {
  const ShixuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '拾序',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const MainPage(),
    );
  }
}

class Task {
  String id;
  String title;
  String category;
  DateTime? dueDate;
  bool isCompleted;

  Task({
    required this.id,
    required this.title,
    this.category = '默认',
    this.dueDate,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'dueDate': dueDate?.toIso8601String(),
        'isCompleted': isCompleted,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        category: json['category'] ?? '默认',
        dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        isCompleted: json['isCompleted'] ?? false,
      );
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  List<Task> _tasks = [];
  List<String> _templates = ['每日例会', '周报撰写', '定期备份'];
  
  // 设置选项
  bool _launchAtStartup = false;
  bool _minimizeToTray = true;
  bool _enableReminders = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString('shixu_tasks');
    if (tasksJson != null) {
      final List<dynamic> list = jsonDecode(tasksJson);
      setState(() {
        _tasks = list.map((e) => Task.fromJson(e)).toList();
      });
    }
    setState(() {
      _launchAtStartup = prefs.getBool('launchAtStartup') ?? false;
      _minimizeToTray = prefs.getBool('minimizeToTray') ?? true;
      _enableReminders = prefs.getBool('enableReminders') ?? true;
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_tasks.map((e) => e.toJson()).toList());
    await prefs.setString('shixu_tasks', data);
  }

  Future<void> _saveSettings(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _addTask(String title, String category) {
    setState(() {
      _tasks.add(Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: category,
      ));
    });
    _saveTasks();
  }

  Future<void> _importExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.bytes != null) {
      var bytes = result.files.single.bytes!;
      var excel = ex.Excel.decodeBytes(bytes);
      int count = 0;

      for (var table in excel.tables.keys) {
        for (var row in excel.tables[table]!.rows.skip(1)) {
          if (row.isNotEmpty && row[0]?.value != null) {
            String title = row[0]!.value.toString();
            String cat = row.length > 1 && row[1]?.value != null ? row[1]!.value.toString() : '导入';
            _tasks.add(Task(
              id: DateTime.now().millisecondsSinceEpoch.toString() + count.toString(),
              title: title,
              category: cat,
            ));
            count++;
          }
        }
      }
      _saveTasks();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 $count 条任务')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildTaskList(),
      _buildTemplates(),
      _buildSettings(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('拾序 - 任务管理'),
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: '导入 Excel',
              onPressed: _importExcel,
            ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_box_outlined), label: '任务'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), label: '模板'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddTaskDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTaskList() {
    if (_tasks.isEmpty) {
      return const Center(child: Text('暂无任务，点击右下角添加'));
    }
    return ListView.builder(
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return ListTile(
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (val) {
              setState(() {
                task.isCompleted = val ?? false;
              });
              _saveTasks();
            },
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text('分类: ${task.category}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () {
              setState(() {
                _tasks.removeAt(index);
              });
              _saveTasks();
            },
          ),
        );
      },
    );
  }

  Widget _buildTemplates() {
    return ListView.builder(
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final tpl = _templates[index];
        return ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(tpl),
          trailing: TextButton(
            child: const Text('使用'),
            onPressed: () {
              _addTask(tpl, '快捷创建');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已基于模板创建任务：$tpl')),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('系统设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SwitchListTile(
          title: const Text('开机启动'),
          subtitle: const Text('开机时自动在后台启动拾序'),
          value: _launchAtStartup,
          onChanged: (val) {
            setState(() => _launchAtStartup = val);
            _saveSettings('launchAtStartup', val);
          },
        ),
        SwitchListTile(
          title: const Text('最小化至系统托盘'),
          subtitle: const Text('关闭主窗口时保持后台运行'),
          value: _minimizeToTray,
          onChanged: (val) {
            setState(() => _minimizeToTray = val);
            _saveSettings('minimizeToTray', val);
          },
        ),
        SwitchListTile(
          title: const Text('后台提醒通知'),
          subtitle: const Text('到达任务提醒时间时弹出通知'),
          value: _enableReminders,
          onChanged: (val) {
            setState(() => _enableReminders = val);
            _saveSettings('enableReminders', val);
          },
        ),
      ],
    );
  }

  void _showAddTaskDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建任务'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '请输入任务名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addTask(controller.text.trim(), '常规');
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
