package com.oma.support;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Supplier;

import com.oma.sms.SmsGateway;
import com.oma.sms.SmsMessage;
import com.oma.sms.SmsSendResult;

/** Records sends and returns scripted results (default: accepted). */
public class FakeSmsGateway implements SmsGateway {

	public final List<SmsMessage> sent = new CopyOnWriteArrayList<>();

	private final Deque<Supplier<SmsSendResult>> script = new ArrayDeque<>();

	public synchronized void thenReturn(Supplier<SmsSendResult> next) {
		script.add(next);
	}

	public synchronized void reset() {
		sent.clear();
		script.clear();
	}

	@Override
	public String providerName() {
		return "fake";
	}

	@Override
	public SmsSendResult send(SmsMessage message) {
		sent.add(message);
		Supplier<SmsSendResult> next;
		synchronized (this) {
			next = script.poll();
		}
		return next != null ? next.get() : SmsSendResult.accepted("fake-" + sent.size());
	}

}
