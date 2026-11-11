# SmartWrite AI Pro

A Flutter Android writing assistant prototype with Arabic/English sample corrections.

## Version 0.1
- Modern Flutter material UI, dark/light mode
- Local text editor, word/character counters, copy button
- Offline sample rule-based corrections
- GitHub Actions release APK workflow

## Important limitation
This is an offline rule-based demo, **not a trained AI model**. Grammar, style and neural NLP models are future phases.

## Build
```bash
flutter pub get
flutter analyze
flutter build apk --release
```

For distribution to other testers, prepare an appropriate signing setup and release process. Do not commit signing keys or passwords.
