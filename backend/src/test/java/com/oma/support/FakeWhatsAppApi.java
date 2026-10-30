package com.oma.support;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Supplier;

import com.oma.whatsapp.WhatsAppApi;

/** Records sends and returns scripted results (default: accepted with wamid "wamid.N"). */
public class FakeWhatsAppApi implements WhatsAppApi {

	public final List<OutgoingMessage> sent = new CopyOnWriteArrayList<>();

	private final Deque<Supplier<SendResult>> script = new ArrayDeque<>();

	public synchronized void thenReturn(Supplier<SendResult> next) {
		script.add(next);
	}

	public synchronized void reset() {
		sent.clear();
		script.clear();
	}

	@Override
	public SendResult send(OutgoingMessage message) {
		sent.add(message);
		Supplier<SendResult> next;
		synchronized (this) {
			next = script.poll();
		}
		return next != null ? next.get() : new SendResult(Outcome.ACCEPTED, "wamid." + sent.size(), null, null);
	}

}
