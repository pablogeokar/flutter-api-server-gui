import 'package:flutter/material.dart';
import 'dart:async';
import 'package:network_info_plus/network_info_plus.dart';
import '../services/api_server.dart';
import '../services/log_service.dart';
import '../services/config_service.dart';
import '../services/database_service.dart';
import '../models/log_entry.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late StreamSubscription _logSubscription;
  late StreamSubscription _statusSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _localIp = 'Carregando...';
  List<LogEntry> _logs = [];
  String _serverStatus = 'Inicializando...';
  int _userCount = 0;
  int _totalRequests = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
    _loadLocalIp();
    _loadStats();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (ApiServer.instance.isRunning) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _initializeServices() {
    _logs = LogService.instance.logs;

    _logSubscription = LogService.instance.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs = LogService.instance.logs;
        });
      }
    });

    _statusSubscription = ApiServer.instance.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _serverStatus = status;
        });
        _updatePulseAnimation();
      }
    });
  }

  void _updatePulseAnimation() {
    if (ApiServer.instance.isRunning) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  Future<void> _loadLocalIp() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP() ?? 'Não disponível';
      if (mounted) {
        setState(() {
          _localIp = ip;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localIp = 'Erro ao obter IP';
        });
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final userCount = await DatabaseService.instance.getUserCount();
      final totalRequests = ConfigService.instance.totalRequests;

      if (mounted) {
        setState(() {
          _userCount = userCount;
          _totalRequests = totalRequests;
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  @override
  void dispose() {
    _logSubscription.cancel();
    _statusSubscription.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '🚀 API Server Local',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.primary),
            onPressed: () => _openSettings(),
            tooltip: 'Configurações',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadLocalIp();
          await _loadStats();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildServerStatusCard(),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 16),
              _buildControlButtons(),
              const SizedBox(height: 24),
              _buildLogsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerStatusCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRunning = ApiServer.instance.isRunning;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isRunning ? _pulseAnimation.value : 1.0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isRunning
                    ? [
                        colorScheme.secondary,
                        colorScheme.secondary.withOpacity(0.8)
                      ]
                    : [
                        colorScheme.outline.withOpacity(0.3),
                        colorScheme.outline.withOpacity(0.1)
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      (isRunning ? colorScheme.secondary : colorScheme.outline)
                          .withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isRunning ? Icons.cloud_done : Icons.cloud_off,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRunning ? 'Servidor Online' : 'Servidor Offline',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _serverStatus,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isRunning) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'http://$_localIp:${ConfigService.instance.serverPort}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (ApiServer.instance.uptime != null)
                    Text(
                      'Tempo ativo: ${_formatUptime(ApiServer.instance.uptime!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
            child: _buildStatCard('👥', 'Usuários', _userCount.toString())),
        const SizedBox(width: 12),
        Expanded(
            child:
                _buildStatCard('📊', 'Requisições', _totalRequests.toString())),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('📝', 'Logs', _logs.length.toString())),
      ],
    );
  }

  Widget _buildStatCard(String emoji, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    final isRunning = ApiServer.instance.isRunning;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _toggleServer,
            icon: Icon(
              isRunning ? Icons.stop : Icons.play_arrow,
              color: Colors.white,
            ),
            label: Text(
              isRunning ? 'Parar Servidor' : 'Iniciar Servidor',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRunning ? Colors.red : Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _restartServer,
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('Reiniciar', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogsSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '📋 Logs Recentes',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _clearLogs,
                  icon: Icon(Icons.clear_all,
                      size: 16, color: colorScheme.primary),
                  label: Text('Limpar',
                      style: TextStyle(color: colorScheme.primary)),
                ),
                TextButton.icon(
                  onPressed: _exportLogs,
                  icon: Icon(Icons.download,
                      size: 16, color: colorScheme.primary),
                  label: Text('Exportar',
                      style: TextStyle(color: colorScheme.primary)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
          ),
          child: _logs.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 48,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhum log ainda',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                        Text(
                          'Os logs aparecerão quando o servidor receber requisições',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: _logs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) => _buildLogItem(_logs[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildLogItem(LogEntry log) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color statusColor = colorScheme.outline;
    if (log.statusCode >= 200 && log.statusCode < 300) {
      statusColor = Colors.green;
    } else if (log.statusCode >= 400 && log.statusCode < 500) {
      statusColor = Colors.orange;
    } else if (log.statusCode >= 500) {
      statusColor = Colors.red;
    }

    Color methodColor = colorScheme.primary;
    switch (log.method.toUpperCase()) {
      case 'GET':
        methodColor = Colors.blue;
        break;
      case 'POST':
        methodColor = Colors.green;
        break;
      case 'PUT':
        methodColor = Colors.orange;
        break;
      case 'DELETE':
        methodColor = Colors.red;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: methodColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              log.method,
              style: theme.textTheme.labelSmall?.copyWith(
                color: methodColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.shortUrl,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              log.statusCode.toString(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            log.formattedTime,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  String _formatUptime(Duration uptime) {
    final hours = uptime.inHours;
    final minutes = uptime.inMinutes % 60;
    final seconds = uptime.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Future<void> _toggleServer() async {
    final server = ApiServer.instance;

    if (server.isRunning) {
      await server.stop();
    } else {
      await server.start();
    }

    await _loadStats();
    setState(() {});
  }

  Future<void> _restartServer() async {
    await ApiServer.instance.restart();
    await _loadStats();
    setState(() {});
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Logs'),
        content: const Text('Tem certeza que deseja limpar todos os logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              LogService.instance.clearLogs();
              Navigator.pop(context);
              setState(() {
                _logs = [];
              });
            },
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLogs() async {
    try {
      final content = await LogService.instance.exportLogsAsText();
      // In a real app, you would use file_picker to save the file
      // For now, we'll just show a dialog with the content
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logs Exportados'),
          content: SingleChildScrollView(
            child: Text(content,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar logs: $e')),
      );
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    ).then((_) {
      _loadLocalIp();
      _loadStats();
    });
  }
}
