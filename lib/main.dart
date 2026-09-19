import 'dart:convert';
import 'dart:io';
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

enum Priority { high, medium, low }

extension PriorityExtension on Priority {
  String get label {
    switch (this) {
      case Priority.high:
        return '高';
      case Priority.medium:
        return '中';
      case Priority.low:
        return '低';
    }
  }

  Color get color {
    switch (this) {
      case Priority.high:
        return Colors.red.shade400;
      case Priority.medium:
        return Colors.orange.shade400;
      case Priority.low:
        return Colors.green.shade400;
    }
  }

  static Priority fromString(String val) {
    if (val.contains('高')) return Priority.high;
    if (val.contains('低')) return Priority.low;
    return Priority.medium;
  }
}

class Task {
  String id;
  String title;
  String category;
  DateTime? dueDate;
  Priority priority;
  String notes;
  bool isCompleted;

  Task({
    required this.id,
    required this.title,
    this.category = '常规',
    this.dueDate,
    this.priority = Priority.medium,
    this.notes = '',
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'dueDate': dueDate?.toIso8601String(),
        'priority': priority.name,
        'notes': notes,
        'isCompleted': isCompleted,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        category: json['category'] ?? '常规',
        dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
        priority: Priority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => Priority.medium,
        ),
        notes: json['notes'] ?? '',
        isCompleted: json['isCompleted'] ?? false,
      );
}

class TaskTemplate {
  String id;
  String name;
  String defaultCategory;
  Priority defaultPriority;

  TaskTemplate({
    required this.id,
    required this.name,
    this.defaultCategory = '常规',
    this.defaultPriority = Priority.medium,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'defaultCategory': defaultCategory,
        'defaultPriority': defaultPriority.name,
      };

  factory TaskTemplate.fromJson(Map<String, dynamic> json) => TaskTemplate(
        id: json['id'],
        name: json['name'],
        defaultCategory: json['defaultCategory'] ?? '常规',
        defaultPriority: Priority.values.firstWhere(
          (e) => e.name == json['defaultPriority'],
          orElse: () => Priority.medium,
        ),
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
  List<TaskTemplate> _templates = [
    TaskTemplate(id: '1', name: '每日例会整理', defaultCategory: '工作', defaultPriority: Priority.high),
    TaskTemplate(id: '2', name: '周报撰写与提交', defaultCategory: '工作', defaultPriority: Priority.medium),
    TaskTemplate(id: '3', name: '系统数据定期备份', defaultCategory: '运维', defaultPriority: Priority.low),
  ];

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
      _tasks = list.map((e) => Task.fromJson(e)).toList();
    }

    final String? tplJson = prefs.getString('shixu_templates');
    if (tplJson != null) {
      final List<dynamic> list = jsonDecode(tplJson);
      _templates = list.map((e) => TaskTemplate.fromJson(e)).toList();
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

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_templates.map((e) => e.toJson()).toList());
    await prefs.setString('shixu_templates', data);
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _addTask(String title, String category, Priority priority, DateTime? dueDate, String notes) {
    setState(() {
      _tasks.add(Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: category.isEmpty ? '常规' : category,
        priority: priority,
        dueDate: dueDate,
        notes: notes,
      ));
    });
    _saveTasks();
  }

  Future<void> _exportExcelTemplate() async {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel['Sheet1'];

    sheet.appendRow([
      ex.TextCellValue('任务标题(必填)'),
      ex.TextCellValue('分类'),
      ex.TextCellValue('截止时间(YYYY-MM-DD)'),
      ex.TextCellValue('优先级(高/中/低)'),
      ex.TextCellValue('备注说明'),
    ]);

    sheet.appendRow([
      ex.TextCellValue('示例：完成项目代码审查'),
      ex.TextCellValue('工作'),
      ex.TextCellValue('2026-10-01'),
      ex.TextCellValue('高'),
      ex.TextCellValue('检查关键架构安全性'),
    ]);

    var bytes = excel.save();
    if (bytes == null) return;

    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存 Excel 示例模板',
      fileName: '拾序_任务导入模板.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (outputPath != null) {
      File(outputPath).writeAsBytesSync(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('示例模板保存成功')),
        );
      }
    }
  }

  Future<void> _importExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    var bytes = result.files.single.bytes!;
    var excel = ex.Excel.decodeBytes(bytes);

    int successCount = 0;
    List<String> errors = [];

    for (var table in excel.tables.keys) {
      var rows = excel.tables[table]!.rows;
      if (rows.isEmpty) continue;

      for (int i = 1; i < rows.length; i++) {
        var row = rows[i];
        if (row.isEmpty) continue;

        String title = row.isNotEmpty && row[0]?.value != null ? row[0]!.value.toString().trim() : '';
        if (title.isEmpty) {
          errors.add('第 ${i + 1} 行：任务标题为空，已跳过');
          continue;
        }

        String category = row.length > 1 && row[1]?.value != null ? row[1]!.value.toString().trim() : '导入';
        
        DateTime? dueDate;
        if (row.length > 2 && row[2]?.value != null) {
          String dateStr = row[2]!.value.toString().trim();
          dueDate = DateTime.tryParse(dateStr);
          if (dueDate == null && dateStr.isNotEmpty) {
            errors.add('第 ${i + 1} 行：日期 [$dateStr] 格式不正确，期望格式 YYYY-MM-DD');
          }
        }

        Priority priority = Priority.medium;
        if (row.length > 3 && row[3]?.value != null) {
          priority = PriorityExtension.fromString(row[3]!.value.toString());
        }

        String notes = row.length > 4 && row[4]?.value != null ? row[4]!.value.toString().trim() : '';

        _tasks.add(Task(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
          title: title,
          category: category.isEmpty ? '导入' : category,
          dueDate: dueDate,
          priority: priority,
          notes: notes,
        ));
        successCount++;
      }
    }

    _saveTasks();
    setState(() {});

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excel 导入结果'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('成功导入 $successCount 条任务。', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('校验异常列表：', style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 6),
                  ...errors.map((e) => Text('• $e', style: const TextStyle(fontSize: 12))),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
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
          if (_selectedIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: '导出示例模板',
              onPressed: _exportExcelTemplate,
            ),
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: '导入 Excel 任务',
              onPressed: _importExcel,
            ),
          ]
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
              onPressed: () => _showTaskEditDialog(),
              child: const Icon(Icons.add),
            )
          : (_selectedIndex == 1
              ? FloatingActionButton(
                  onPressed: () => _showTemplateEditDialog(),
                  child: const Icon(Icons.add),
                )
              : null),
    );
  }

  Widget _buildTaskList() {
    if (_tasks.isEmpty) {
      return const Center(
        child: Text('暂无任务，可点击右下角新增或从 Excel 导入'),
      );
    }
    return ListView.builder(
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        final DateFormat formatter = DateFormat('yyyy-MM-dd');
        
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
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: task.priority.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '优先级: ${task.priority.label}',
                  style: TextStyle(fontSize: 10, color: task.priority.color),
                ),
              ),
              const SizedBox(width: 8),
              Text('分类: ${task.category}', style: const TextStyle(fontSize: 12)),
              if (task.dueDate != null) ...[
                const SizedBox(width: 8),
                Text('截止: ${formatter.format(task.dueDate!)}', style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showTaskEditDialog(task: task, index: index);
              } else if (value == 'save_template') {
                _templates.add(TaskTemplate(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: task.title,
                  defaultCategory: task.category,
                  defaultPriority: task.priority,
                ));
                _saveTemplates();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已将 [${task.title}] 保存为新模板')),
                );
              } else if (value == 'delete') {
                setState(() {
                  _tasks.removeAt(index);
                });
                _saveTasks();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              const PopupMenuItem(value: 'save_template', child: Text('保存为模板')),
              const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTemplates() {
    if (_templates.isEmpty) {
      return const Center(child: Text('暂无快捷模板，点击右下角添加'));
    }
    return ListView.builder(
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final tpl = _templates[index];
        return ListTile(
          leading: const Icon(Icons.bookmark_outline),
          title: Text(tpl.name),
          subtitle: Text('默认分类: ${tpl.defaultCategory} | 优先级: ${tpl.defaultPriority.label}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                child: const Text('使用'),
                onPressed: () {
                  _addTask(tpl.name, tpl.defaultCategory, tpl.defaultPriority, null, '');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已基于模板创建任务：${tpl.name}')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () {
                  setState(() {
                    _templates.removeAt(index);
                  });
                  _saveTemplates();
                },
              ),
            ],
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
          title: const Text('开机自启动'),
          subtitle: const Text('系统启动时自动在后台启动拾序'),
          value: _launchAtStartup,
          onChanged: (val) {
            setState(() => _launchAtStartup = val);
            _saveSetting('launchAtStartup', val);
          },
        ),
        SwitchListTile(
          title: const Text('关闭时最小化至系统托盘'),
          subtitle: const Text('点击关闭按钮保持后台运行，不完全退出应用'),
          value: _minimizeToTray,
          onChanged: (val) {
            setState(() => _minimizeToTray = val);
            _saveSetting('minimizeToTray', val);
          },
        ),
        SwitchListTile(
          title: const Text('后台提醒通知'),
          subtitle: const Text('到达任务截止时间时弹出桌面/系统通知'),
          value: _enableReminders,
          onChanged: (val) {
            setState(() => _enableReminders = val);
            _saveSetting('enableReminders', val);
          },
        ),
        const Divider(height: 30),
        const Text('数据管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined, color: Colors.red),
          title: const Text('清空所有任务数据', style: TextStyle(color: Colors.red)),
          onTap: () async {
            bool? confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('确认清空？'),
                content: const Text('此操作将删除所有本地任务且无法撤销。'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空', style: TextStyle(color: Colors.red))),
                ],
              ),
            );
            if (confirm == true) {
              setState(() => _tasks.clear());
              _saveTasks();
            }
          },
        ),
      ],
    );
  }

  void _showTaskEditDialog({Task? task, int? index}) {
    final titleController = TextEditingController(text: task?.title ?? '');
    final categoryController = TextEditingController(text: task?.category ?? '常规');
    final notesController = TextEditingController(text: task?.notes ?? '');
    Priority priority = task?.priority ?? Priority.medium;
    DateTime? selectedDate = task?.dueDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(task == null ? '新建任务' : '编辑任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '任务名称(必填)'),
                  autofocus: true,
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: '分类'),
                ),
                DropdownButtonFormField<Priority>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: '优先级'),
                  items: Priority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => priority = val);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(selectedDate == null ? '截止时间: 未设置' : '截止: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}'),
                    const Spacer(),
                    TextButton(
                      child: const Text('选择日期'),
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setDialogState(() => selectedDate = picked);
                      },
                    ),
                  ],
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: '备注'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                if (task == null) {
                  _addTask(
                    titleController.text.trim(),
                    categoryController.text.trim(),
                    priority,
                    selectedDate,
                    notesController.text.trim(),
                  );
                } else if (index != null) {
                  setState(() {
                    _tasks[index].title = titleController.text.trim();
                    _tasks[index].category = categoryController.text.trim();
                    _tasks[index].priority = priority;
                    _tasks[index].dueDate = selectedDate;
                    _tasks[index].notes = notesController.text.trim();
                  });
                  _saveTasks();
                }
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateEditDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController(text: '常规');
    Priority priority = Priority.medium;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新建快捷模板'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '模板名称'),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: '默认分类'),
              ),
              DropdownButtonFormField<Priority>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: '默认优先级'),
                items: Priority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => priority = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                setState(() {
                  _templates.add(TaskTemplate(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    defaultCategory: categoryController.text.trim(),
                    defaultPriority: priority,
                  ));
                });
                _saveTemplates();
                Navigator.pop(context);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}
