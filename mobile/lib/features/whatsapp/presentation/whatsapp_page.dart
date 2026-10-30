import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/resource.dart';
import '../../../core/widgets/state_views.dart';
import 'whatsapp_cubit.dart';
import 'whatsapp_message_tile.dart';

class WhatsAppPage extends StatelessWidget {
  const WhatsAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WhatsAppCubit>();
    return BlocBuilder<WhatsAppCubit, Resource<WhatsAppOverview>>(
      builder: (context, state) {
        final connected = state is Loaded<WhatsAppOverview> && state.data.status.connected;
        return Scaffold(
          appBar: AppBar(title: const Text('WhatsApp')),
          floatingActionButton: connected
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await context.push('/whatsapp/new');
                    cubit.load();
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('New message'),
                )
              : null,
          body: ResourceView<WhatsAppOverview>(
            resource: state,
            onRetry: cubit.load,
            builder: (data) {
              if (!data.status.connected) {
                return const EmptyView(
                  icon: Icons.link_off,
                  title: 'WhatsApp Business is not connected',
                  message:
                      'Automatic alerts need a WhatsApp Business number connected to the server. '
                      'See docs/04-whatsapp-setup.md. Until then, use manual alerts from Home.',
                );
              }
              if (data.messages.isEmpty) {
                return const EmptyView(
                  icon: Icons.chat_outlined,
                  title: 'No messages yet',
                  message:
                      'Messages you send here are tracked. If one is not delivered in time, '
                      'your relay phone texts the person.',
                );
              }
              return RefreshIndicator(
                onRefresh: cubit.load,
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: data.messages.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => WaMessageTile(message: data.messages[i]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
