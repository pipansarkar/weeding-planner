import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/access_provider.dart';

/// Shown in place of a domain screen's content when the current user does
/// not have approved access to [section]. Lets them request access (or
/// re-request after a rejection/revocation); the owner reviews requests via
/// AccessRequestsScreen.
class RequestAccessBanner extends StatelessWidget {
  final String section;

  const RequestAccessBanner({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AccessProvider>().accessStatusFor(section);
    final pending = status == 'pending';
    final rejectedOrRevoked = status == 'rejected' || status == 'revoked';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              pending
                  ? 'Your request for access is waiting for approval.'
                  : rejectedOrRevoked
                      ? 'Your access to this section was not approved.'
                      : 'You need permission to view this section.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            if (!pending)
              FilledButton(
                onPressed: () => context.read<AccessProvider>().requestSectionAccess(section),
                child: Text(rejectedOrRevoked ? 'Request access again' : 'Request access'),
              ),
          ],
        ),
      ),
    );
  }
}
