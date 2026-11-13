package com.ngclass.backend.announcements.domain;

/** Who reads an announcement (spec 08): the pupils, their parents, or both. */
public enum Audience {
	PUPILS,
	PARENTS,
	BOTH;

	public boolean pupils() {
		return this != PARENTS;
	}

	public boolean parents() {
		return this != PUPILS;
	}
}
