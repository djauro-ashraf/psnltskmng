import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/note_store.dart';

/// The notes controller (the notes file + the day-end check). The composition
/// root overrides it with the real store (app/dependencies.dart); without an
/// override (tests, previews) the notes live in memory only.
final notesControllerProvider = Provider<NotesController>(
  (ref) => NotesController(store: InMemoryNoteStore()),
);
