import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/config_service.dart';
import '../services/api_server.dart';
import '../services/database_service.dart';
import '../services/log_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _portController;
  late final TextEditingController _databasePathController;

  bool _autoStartServer = true;
  bool _minimizeToTray = true;
  bool _isLoading = false;
  Map<String, dynamic>? _databaseInfo;
  Map<String, dynamic>? _serverStats;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadSettings();
    _loadDatabaseInfo();
    _loadServerStats();
  }

  void _initializeControllers() {
    _portController = TextEditingController();
    _databasePathController = TextEditingController();
  }

  Future<void> _loadSettings() async {
    final config = ConfigService.instance;
    await config.initialize();

    setState(() {
      _portController.text = config.serverPort.toString();
      _databasePathController.text = config.databasePath;
      _autoStartServer = config.autoStartServer;
      _minimizeToTray = config.minimizeToTray;
    });
  }

  Future<void> _loadDatabaseInfo() async {
    try {
      final info = await DatabaseService.instance.getDatabaseInfo();
      setState(() {
        _databaseInfo = info;
      });
    } catch (e) {
      print('Error loading database info: $e');
    }
  }

  Future<void> _loadServerStats() async {
    final logService = LogService.instance;
    setState(() {
      _serverStats = {
        'total_logs': logService.logCount,
        'successful_requests': logService.successfulRequests,
        'error_requests': logService.errorRequests,
        'average_response_time': logService.averageResponseTime,
        'method_stats': logService.getMethodStats(),
        'status_stats': logService.getStatusCodeStats(),
      };
    });
  }

  @override
  void dispose() {
    _portController.dispose();
    _databasePathController.dispose();
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
          '⚙️ Configurações',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildServerSettingsCard(),
            const SizedBox(height: 16),
            _buildAppSettingsCard(),
            const SizedBox(height: 16),
            _buildDatabaseInfoCard(),
            const SizedBox(height: 16),
            _buildStatisticsCard(),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildServerSettingsCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns, color: colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Configurações do Servidor',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: 'Porta do Servidor',
                hintText: 'Ex: 3000',
                prefixIcon: Icon(Icons.router, color: colorScheme.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _databasePathController,
              decoration: InputDecoration(
                labelText: 'Caminho do Banco de Dados',
                hintText: 'Ex: api_server.db',
                prefixIcon: Icon(Icons.storage, color: colorScheme.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Iniciar servidor automaticamente'),
              subtitle:
                  const Text('O servidor será iniciado quando o app abrir'),
              value: _autoStartServer,
              onChanged: (value) {
                setState(() {
                  _autoStartServer = value;
                });
              },
              activeColor: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSettingsCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_applications,
                    color: colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Configurações do Aplicativo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Minimizar para bandeja'),
              subtitle:
                  const Text('O app será minimizado para a bandeja do sistema'),
              value: _minimizeToTray,
              onChanged: (value) {
                setState(() {
                  _minimizeToTray = value;
                });
              },
              activeColor: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseInfoCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Informações do Banco de Dados',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_databaseInfo != null) ...[
              _buildInfoRow('Caminho', _databaseInfo!['path'] ?? 'N/A'),
              _buildInfoRow('Tamanho', '${_databaseInfo!['size_kb']} KB'),
              _buildInfoRow('Usuários', '${_databaseInfo!['user_count']}'),
              _buildInfoRow(
                  'Status', _databaseInfo!['is_open'] ? 'Aberto' : 'Fechado'),
            ] else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Estatísticas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_serverStats != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      '📊',
                      'Total de Logs',
                      '${_serverStats!['total_logs']}',
                      colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      '✅',
                      'Sucessos',
                      '${_serverStats!['successful_requests']}',
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      '❌',
                      'Erros',
                      '${_serverStats!['error_requests']}',
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      '⏱️',
                      'Tempo Médio',
                      '${_serverStats!['average_response_time'].toStringAsFixed(1)}ms',
                      colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Métodos HTTP',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ..._buildMethodStats(),
            ] else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String label, String value, Color color) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMethodStats() {
    if (_serverStats == null) return [];

    final methodStats = _serverStats!['method_stats'] as Map<String, dynamic>;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return methodStats.entries.map((entry) {
      Color methodColor = colorScheme.primary;
      switch (entry.key.toUpperCase()) {
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
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: methodColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.key,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: methodColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              entry.value.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveSettings,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, color: Colors.white),
            label: Text(
              _isLoading ? 'Salvando...' : 'Salvar Configurações',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportLogs,
                icon: const Icon(Icons.download),
                label: const Text('Exportar Logs'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetSettings,
                icon: const Icon(Icons.restore),
                label: const Text('Restaurar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final config = ConfigService.instance;
      final port = int.tryParse(_portController.text);

      if (port == null || !config.isValidPort(port)) {
        throw Exception('Porta inválida. Use uma porta entre 1024 e 65535.');
      }

      if (_databasePathController.text.trim().isEmpty) {
        throw Exception('Caminho do banco de dados não pode estar vazio.');
      }

      // Save settings
      await config.setServerPort(port);
      await config.setDatabasePath(_databasePathController.text.trim());
      await config.setAutoStartServer(_autoStartServer);
      await config.setMinimizeToTray(_minimizeToTray);

      // Restart server if running and port changed
      if (ApiServer.instance.isRunning && port != config.serverPort) {
        await ApiServer.instance.restart();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Configurações salvas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportLogs() async {
    try {
      final content = await LogService.instance.exportLogsAsText();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logs Exportados'),
          content: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
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

  Future<void> _resetSettings() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar Configurações'),
        content: const Text(
            'Tem certeza que deseja restaurar todas as configurações para os valores padrão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ConfigService.instance.resetToDefaults();
              await _loadSettings();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configurações restauradas com sucesso!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }
}
