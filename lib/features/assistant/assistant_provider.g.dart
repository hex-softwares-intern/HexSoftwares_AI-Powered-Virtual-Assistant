// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Assistant)
final assistantProvider = AssistantProvider._();

final class AssistantProvider
    extends $NotifierProvider<Assistant, AssistantData> {
  AssistantProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assistantProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assistantHash();

  @$internal
  @override
  Assistant create() => Assistant();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AssistantData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AssistantData>(value),
    );
  }
}

String _$assistantHash() => r'dcbeceedde7bbddda97d083b9e742a3bfc0d7904';

abstract class _$Assistant extends $Notifier<AssistantData> {
  AssistantData build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AssistantData, AssistantData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AssistantData, AssistantData>,
              AssistantData,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
