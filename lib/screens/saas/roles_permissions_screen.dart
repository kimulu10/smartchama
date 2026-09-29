import 'package:flutter/material.dart';
import 'package:smartchama/models/role_permission_model.dart';
import 'package:smartchama/services/organization_service.dart';
import 'package:smartchama/services/role_permission_service.dart';

/// Advanced role-based access control. Assign roles and customise
/// feature-level permissions per member.
class RolesPermissionsScreen extends StatefulWidget {
  final String organizationId;
  const RolesPermissionsScreen({super.key, required this.organizationId});

  @override
  State<RolesPermissionsScreen> createState() =>
      _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends State<RolesPermissionsScreen> {
  final OrganizationService _orgService = OrganizationService();
  final RolePermissionService _permService = RolePermissionService();
  List<MemberRole> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _members = await _orgService.getMembers(widget.organizationId);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          appBar: AppBar(title: const Text('Roles & Permissions')),
          body: const Center(child: CircularProgressIndicator()));
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Roles & Permissions'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Members'),
              Tab(text: 'Permission Matrix'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MembersList(
              members: _members,
              service: _permService,
              organizationId: widget.organizationId,
              onChanged: _load,
            ),
            _MatrixTab(),
          ],
        ),
      ),
    );
  }
}

class _MembersList extends StatelessWidget {
  final List<MemberRole> members;
  final RolePermissionService service;
  final String organizationId;
  final VoidCallback onChanged;

  const _MembersList({
    required this.members,
    required this.service,
    required this.organizationId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(child: Text('No members yet.'));
    }
    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (_, i) {
        final m = members[i];
        final perms = m.effectivePermissions;
        return ExpansionTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(m.memberName ?? m.userId),
          subtitle: Text(m.role.displayName),
          trailing: DropdownButton<OrganizationRole>(
            value: m.role,
            underline: const SizedBox(),
            items: OrganizationRole.values
                .map((r) => DropdownMenuItem(
                    value: r, child: Text(r.displayName)))
                .toList(),
            onChanged: (r) async {
              await service.assignRole(
                organizationId: organizationId,
                userId: m.userId,
                role: r!,
              );
              onChanged();
            },
          ),
          children: Permission.values.map((p) {
            return CheckboxListTile(
              title: Text(p.displayName),
              value: perms.contains(p),
              onChanged: (checked) async {
                if (checked == true) {
                  await service.grantPermission(
                      organizationId: organizationId,
                      userId: m.userId,
                      permission: p);
                } else {
                  await service.revokePermission(
                      organizationId: organizationId,
                      userId: m.userId,
                      permission: p);
                }
                onChanged();
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class _MatrixTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final roles = OrganizationRole.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Permission')),
          ...roles.map((r) => DataColumn(label: Text(r.displayName))),
        ],
        rows: Permission.values.map((p) {
          return DataRow(
            cells: [
              DataCell(Text(p.displayName)),
              ...roles.map((r) {
                final has = defaultPermissionTemplate[r]?.contains(p) ?? false;
                return DataCell(Icon(
                  has ? Icons.check_circle : Icons.cancel,
                  color: has ? Colors.green : Colors.grey.shade300,
                  size: 18,
                ));
              }),
            ],
          );
        }).toList(),
      ),
    );
  }
}
