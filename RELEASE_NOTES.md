# Release Notes - Version 1.0.0

## Что нового

### Улучшения UX
- **Улучшена авторизация**: Теперь при неправильных данных показывается понятное сообщение об ошибке с подробностями
- **Оптимизирована производительность**: Устранены рывки при прокрутке, приложение работает более плавно
- **Обновлён дизайн приветствия**: Современный дизайн диалога принятия правил с использованием фирменных цветов

### Исправления ошибок
- Исправлена работа кнопки выхода из аккаунта - теперь корректно перенаправляет на страницу входа
- Исправлено отображение выпадающих списков статусов - фон активного элемента теперь не выходит за границы
- Исправлена последовательность показа подсказок при первом входе - теперь показываются только после принятия правил

### Навигация
- Упрощено меню "Ещё" - убрана дублирующая кнопка выхода

---

## What's New (English for App Store)

### UX Improvements
- **Enhanced login experience**: Clear error messages displayed when credentials are incorrect
- **Performance optimization**: Smoother scrolling throughout the app
- **Updated welcome design**: Modern terms acceptance dialog with brand colors

### Bug Fixes
- Fixed logout button - now properly redirects to login screen
- Fixed dropdown status menus - active item background now stays within bounds
- Fixed onboarding tutorial sequence - now shows only after accepting terms

### Navigation
- Simplified "More" menu - removed duplicate logout button

---

## Краткое описание для магазинов (до 500 символов)

**Русский:**
Обновление включает улучшения производительности, исправления ошибок и обновлённый дизайн. Приложение теперь работает быстрее и плавнее. Улучшена обратная связь при авторизации, исправлена навигация и оптимизирована прокрутка контента.

**English:**
This update includes performance improvements, bug fixes, and design updates. The app now runs faster and smoother. Enhanced login feedback, fixed navigation issues, and optimized scrolling performance.

---

## Технические детали (для внутреннего использования)

### Изменённые файлы:
- `lib/src/features/home/presentation/home_screen.dart` - showcase sequence, terms dialog design
- `lib/src/features/auth/presentation/login_screen.dart` - error handling
- `lib/src/features/profile/presentation/profile_screen.dart` - logout navigation
- `lib/src/features/more/presentation/more_sheet.dart` - removed duplicate logout
- `lib/src/features/tracks/presentation/tracks_screen.dart` - dropdown styling
- `lib/src/features/invoices/presentation/invoices_screen.dart` - dropdown styling

### Оптимизации:
- Добавлены `RepaintBoundary` для изоляции перерисовки виджетов
- Настроены параметры кэширования изображений
- Добавлен `cacheExtent` для предзагрузки контента
