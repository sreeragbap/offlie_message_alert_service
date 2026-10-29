package com.oma.sms;

import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
class SmsConfig {

	@Bean
	@ConditionalOnMissingBean(SmsGateway.class)
	SmsGateway loggingSmsGateway() {
		return new LoggingSmsGateway();
	}

}
