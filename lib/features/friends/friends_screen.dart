import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:rocis_schedule/features/friends/friend_provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/widgets/app_text_field.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final friendProvider = context.watch<FriendProvider?>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('friends')),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _showAddFriendDialog(context),
          ),
        ],
      ),
      body: friendProvider == null
          ? Center(child: Text(l10n.translate('login_for_friends')))
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: l10n.translate('friends_list')),
                      Tab(text: l10n.translate('requests')),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _FriendsList(friends: friendProvider.friends),
                        _RequestsList(uid: friendProvider.uid),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('add_friend')),
        content: AppTextField(
          label: l10n.translate('email_address'),
          hint: 'enter friend\'s email',
          controller: controller,
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = controller.text.trim();
              if (email.isNotEmpty) {
                try {
                  await context.read<FriendProvider?>()?.sendRequest(email);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.translate('friend_request_sent')),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              }
            },
            child: Text(l10n.translate('send_request')),
          ),
        ],
      ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  final List<Friend> friends;
  const _FriendsList({required this.friends});

  void _showRemoveFriendDialog(BuildContext context, Friend friend) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('remove_friend')),
        content: Text(l10n.translate('confirm_remove_friend')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              await context.read<FriendProvider?>()?.removeFriend(friend.uid);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(
              l10n.translate('remove'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (friends.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('no_friends'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: friends.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final friend = friends[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            title: Text(
              friend.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              friend.university ?? friend.email,
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            trailing: Icon(
              Icons.compare_arrows,
              color: Colors.white.withOpacity(0.3),
            ),
            onTap: () {
              final myEvents = context.read<CourseProvider>().events;
              context.push(
                '/friends/compare',
                extra: {
                  'myEvents': myEvents,
                  'friendEvents': <ScheduleEvent>[], // Placeholder
                  'friendName': friend.name,
                },
              );
            },
            onLongPress: () => _showRemoveFriendDialog(context, friend),
          ),
        );
      },
    );
  }
}

class _RequestsList extends StatefulWidget {
  final String uid;
  const _RequestsList({required this.uid});

  @override
  State<_RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends State<_RequestsList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendProvider?>()?.loadRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendProvider?>();
    final l10n = AppLocalizations.of(context)!;

    if (provider == null || provider.pendingRequests.isEmpty) {
      return Center(
        child: Text(
          l10n.translate('requests') == 'Requests'
              ? 'No pending requests'
              : 'אין בקשות ממתינות',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.pendingRequests.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final request = provider.pendingRequests[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  child: Text(
                    request.name.isNotEmpty
                        ? request.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                title: Text(
                  request.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(request.email),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => provider.acceptRequest(request.uid),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF18221D),
                        foregroundColor: const Color(0xFF9BE9BC),
                      ),
                      child: Text(l10n.translate('accept')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => provider.declineRequest(request.uid),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF261818),
                        foregroundColor: const Color(0xFFE9B7B7),
                      ),
                      child: Text(l10n.translate('decline')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
