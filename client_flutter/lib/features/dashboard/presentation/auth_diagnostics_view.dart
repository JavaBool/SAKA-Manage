import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:client_flutter/core/db_helper.dart';
import 'package:client_flutter/core/theme.dart';

class AuthDiagnosticsView extends StatefulWidget {
  const AuthDiagnosticsView({super.key});

  @override
  State<AuthDiagnosticsView> createState() => _AuthDiagnosticsViewState();
}

class _AuthDiagnosticsViewState extends State<AuthDiagnosticsView> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  
  // Real-time values
  bool? _accessTokenExists;
  bool? _userIdExists;
  String? _userId;
  String? _jwtExpString;
  int? _jwtRemainingSeconds;
  String? _jwtSub;
  String? _jwtRole;
  String? _dbType;
  int? _dbTokensCount;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _isLoading = true;
    });

    await _loadLiveDiagnostics();
    await _loadEvents();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadEvents() async {
    final events = await DbHelper.getAuthEvents();
    setState(() {
      _events = events;
    });
  }

  Future<void> _loadLiveDiagnostics() async {
    const storage = FlutterSecureStorage();
    try {
      final token = await storage.read(key: 'access_token');
      final userId = await storage.read(key: 'user_id');

      _accessTokenExists = token != null;
      _userIdExists = userId != null;
      _userId = userId;

      if (token != null) {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64.normalize(payload);
          final decoded = utf8.decode(base64.decode(normalized));
          final map = json.decode(decoded) as Map<String, dynamic>;
          
          final expVal = map['exp'];
          _jwtSub = map['sub']?.toString();
          _jwtRole = map['role']?.toString();

          if (expVal is int) {
            final expTime = DateTime.fromMillisecondsSinceEpoch(expVal * 1000).toUtc();
            _jwtExpString = expTime.toLocal().toString();
            final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            _jwtRemainingSeconds = expVal - nowSeconds;
          } else {
            _jwtExpString = "N/A (Missing exp claim)";
            _jwtRemainingSeconds = null;
          }
        }
      } else {
        _jwtExpString = null;
        _jwtRemainingSeconds = null;
        _jwtSub = null;
        _jwtRole = null;
      }

      final db = await DbHelper.database;
      _dbType = "SQLite (Ffi/Mobile)";
      final tokenMaps = await db.rawQuery("SELECT COUNT(*) as count FROM sqlite_master WHERE type='table' AND name='users'");
      if (tokenMaps.isNotEmpty && (tokenMaps.first['count'] as int) > 0) {
        final userCountQuery = await db.rawQuery("SELECT COUNT(*) as count FROM users");
        _dbTokensCount = userCountQuery.isNotEmpty ? (userCountQuery.first['count'] as int) : 0;
      } else {
        _dbTokensCount = 0;
      }
    } catch (e) {
      print("Error loading live diagnostics: $e");
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text("Clear Event History", style: TextStyle(color: AppTheme.textMain)),
        content: const Text("Are you sure you want to clear all authentication diagnostic logs?", style: TextStyle(color: AppTheme.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("CLEAR"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await DbHelper.database;
      await db.delete('auth_events');
      await _refreshAll();
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'login_success':
      case 'startup_session_restoration':
        return AppTheme.success;
      case 'jwt_expiration':
      case 'http_401':
      case 'unexpected_exception':
      case 'storage_read_failure':
        return AppTheme.danger;
      case 'logout':
        return AppTheme.primary;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live Status Overview Card
                Card(
                  color: AppTheme.darkCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Live Auth State Diagnostics",
                              style: TextStyle(
                                color: AppTheme.textMain,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: AppTheme.primary, size: 20),
                              onPressed: _refreshAll,
                              tooltip: "Refresh Diagnostics",
                            ),
                          ],
                        ),
                        const Divider(color: AppTheme.borderColor),
                        const SizedBox(height: 8),
                        _buildDiagnosticRow(
                          "Access Token Exists",
                          _accessTokenExists == true ? "YES" : "NO",
                          valueColor: _accessTokenExists == true ? AppTheme.success : AppTheme.danger,
                        ),
                        _buildDiagnosticRow(
                          "User ID Exists",
                          _userIdExists == true ? "YES" : "NO",
                          valueColor: _userIdExists == true ? AppTheme.success : AppTheme.danger,
                        ),
                        if (_userId != null)
                          _buildDiagnosticRow("Saved User ID", _userId!),
                        if (_jwtSub != null)
                          _buildDiagnosticRow("JWT sub (User ID Claim)", _jwtSub!),
                        if (_jwtRole != null)
                          _buildDiagnosticRow("JWT role Claim", _jwtRole!),
                        if (_jwtExpString != null)
                          _buildDiagnosticRow("JWT Expires At", _jwtExpString!),
                        if (_jwtRemainingSeconds != null)
                          _buildDiagnosticRow(
                            "JWT Remaining Time",
                            _jwtRemainingSeconds! > 0
                                ? "${(_jwtRemainingSeconds! / 3600).toStringAsFixed(2)} hours (${_jwtRemainingSeconds}s)"
                                : "Expired (${_jwtRemainingSeconds}s ago)",
                            valueColor: _jwtRemainingSeconds! > 0 ? AppTheme.success : AppTheme.danger,
                          ),
                        _buildDiagnosticRow("Database Engine", _dbType ?? "SQLite"),
                        _buildDiagnosticRow("Local Cached Users count", "${_dbTokensCount ?? 0}"),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // History Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Authentication Event History (Max 100)",
                      style: TextStyle(
                        color: AppTheme.textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_events.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.danger, size: 18),
                        label: const Text("CLEAR LOGS", style: TextStyle(color: AppTheme.danger, fontSize: 12)),
                        onPressed: _clearLogs,
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_events.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(Icons.history_toggle_off, color: AppTheme.textMuted, size: 48),
                        SizedBox(height: 12),
                        Text(
                          "No authentication events recorded yet.",
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      final type = event['event_type'] as String? ?? 'unknown';
                      final timestampStr = event['timestamp'] as String? ?? '';
                      final detailsStr = event['details'] as String? ?? '{}';
                      
                      Map<String, dynamic> details = {};
                      try {
                        details = jsonDecode(detailsStr);
                      } catch (_) {}

                      DateTime? localTime;
                      if (timestampStr.isNotEmpty) {
                        try {
                          localTime = DateTime.parse(timestampStr).toLocal();
                        } catch (_) {}
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getEventColor(type),
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  type.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _getEventColor(type),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  localTime != null
                                      ? "${localTime.month}/${localTime.day} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}:${localTime.second.toString().padLeft(2, '0')}"
                                      : timestampStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              details['logout_reason'] != null
                                  ? "Reason: ${details['logout_reason']}"
                                  : (details['endpoint_involved'] != null
                                      ? "Route: ${details['endpoint_involved']}"
                                      : "Details loaded"),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.borderColor),
                                  ),
                                  child: SelectableText(
                                    const JsonEncoder.withIndent('  ').convert(details),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: AppTheme.textMain,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
  }

  Widget _buildDiagnosticRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppTheme.textMain,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
