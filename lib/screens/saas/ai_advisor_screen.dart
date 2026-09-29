import 'package:flutter/material.dart';
import 'package:smartchama/models/ai_advisor_model.dart';
import 'package:smartchama/services/ai_advisor_service.dart';

/// AI Financial Advisor: insights, loan recommendations, savings advice,
/// investment suggestions and cash-flow forecasts for the tenant.
class AiAdvisorScreen extends StatefulWidget {
  final String organizationId;
  const AiAdvisorScreen({super.key, required this.organizationId});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final AiAdvisorService _service = AiAdvisorService();
  List<AdvisorInsight> _insights = [];
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _insights = await _service.getInsights(widget.organizationId);
    setState(() => _loading = false);
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    await _service.generateInsights(organizationId: widget.organizationId);
    await _load();
    setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Financial Advisor')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generating ? null : _generate,
        label: _generating
            ? const Text('Analyzing...')
            : const Text('Generate Insights'),
        icon: const Icon(Icons.auto_awesome),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _insights.isEmpty
              ? const Center(
                  child: Text(
                      'No insights yet. Tap "Generate Insights" to analyze.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _insights.length,
                  itemBuilder: (_, i) => _InsightCard(_insights[i]),
                ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final AdvisorInsight insight;
  const _InsightCard(this.insight);

  Color get _color {
    switch (insight.severity) {
      case AdvisorSeverity.positive:
        return Colors.green;
      case AdvisorSeverity.warning:
        return Colors.orange;
      case AdvisorSeverity.critical:
        return Colors.red;
      case AdvisorSeverity.info:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _color.withOpacity(0.15),
          child: Icon(insight.category.icon, color: _color),
        ),
        title: Text(insight.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(insight.detail),
        ),
        trailing: Chip(
          label: Text(insight.category.displayName),
          backgroundColor: Colors.grey.shade100,
        ),
      ),
    );
  }
}
