package com.ngclass.backend.school.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** A level the teacher adds: French name, Arabic name (optional, French shown instead). */
public record LevelRequest(@NotBlank @Size(max = 40) String nameFr, @Size(max = 60) String nameAr) {
}
