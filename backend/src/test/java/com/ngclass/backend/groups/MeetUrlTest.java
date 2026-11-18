package com.ngclass.backend.groups;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.ngclass.backend.common.ApiException;
import com.ngclass.backend.groups.service.GroupService;
import org.junit.jupiter.api.Test;

/** A visio link is cleaned before it is checked, as the app does (bug 2026-11-18). */
class MeetUrlTest {
	@Test
	void theSpacesAndCapitalsOfAPhoneKeyboardAreCleaned() {
		assertThat(GroupService.meetUrl("https: //www.whatsapp.com")).isEqualTo("https://www.whatsapp.com");
		assertThat(GroupService.meetUrl(" Https://meet.google.com/ abc-defg-hij ")).isEqualTo("https://meet.google.com/abc-defg-hij");
	}

	@Test
	void aMissingHttpsIsAddedAndHttpBecomesHttps() {
		assertThat(GroupService.meetUrl("meet.google.com/abc-defg-hij")).isEqualTo("https://meet.google.com/abc-defg-hij");
		assertThat(GroupService.meetUrl("http://zoom.us/j/123")).isEqualTo("https://zoom.us/j/123");
	}

	@Test
	void emptyIsNoLinkAndWhatIsNotALinkIsRefused() {
		assertThat(GroupService.meetUrl("  ")).isNull();
		assertThatThrownBy(() -> GroupService.meetUrl("bonjour")).isInstanceOf(ApiException.class);
		assertThatThrownBy(() -> GroupService.meetUrl("ftp://files.example.com")).isInstanceOf(ApiException.class);
	}
}
