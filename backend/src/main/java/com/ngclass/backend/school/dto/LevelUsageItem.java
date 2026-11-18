package com.ngclass.backend.school.dto;

import com.ngclass.backend.common.LocalizedText;
import java.util.UUID;

/**
 * A level in the teacher's settings: [own] when she added it (she can rename or delete it), with how many
 * of her groups and pupils use it (archived ones included).
 */
public record LevelUsageItem(UUID id, LocalizedText name, boolean own, long groupCount, long studentCount) {
}
