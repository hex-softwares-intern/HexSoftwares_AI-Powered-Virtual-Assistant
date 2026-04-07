enum AssistantState { idle, listening, thinking, speaking, error }

extension AssistantStateX on AssistantState {
  String get label => switch (this) {
    AssistantState.idle => 'Say something',
    AssistantState.listening => 'Listening...',
    AssistantState.thinking => 'Thinking...',
    AssistantState.speaking => 'Speaking...',
    AssistantState.error => 'Something went wrong',
  };
}
