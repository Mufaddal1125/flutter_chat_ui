import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_mentions/flutter_mentions.dart';
import '../models/send_button_visibility_mode.dart';
import 'attachment_button.dart';
import 'inherited_chat_theme.dart';
import 'inherited_l10n.dart';
import 'input_text_field_controller.dart';
import 'send_button.dart';

class NewLineIntent extends Intent {
  const NewLineIntent();
}

class SendMessageIntent extends Intent {
  const SendMessageIntent();
}

/// A class that represents bottom bar widget with a text field, attachment and
/// send buttons inside. By default hides send button when text field is empty.
class Input extends StatefulWidget {
  /// Creates [Input] widget.
  const Input({
    super.key,
    this.isAttachmentUploading,
    this.mentions,
    this.onAttachmentPressed,
    required this.onSendPressed,
    this.onTextChanged,
    this.onTextFieldTap,
    required this.sendButtonVisibilityMode,
    this.suggestionListDecoration,
    this.replyingToMessage,
    this.onCancelReply,
  });

  final List<Mention>? mentions;

  final BoxDecoration? suggestionListDecoration;

  final Function()? onCancelReply;

  /// Whether attachment is uploading. Will replace attachment button with a
  /// [CircularProgressIndicator]. Since we don't have libraries for
  /// managing media in dependencies we have no way of knowing if
  /// something is uploading so you need to set this manually.
  final bool? isAttachmentUploading;

  /// See [AttachmentButton.onPressed].
  final void Function()? onAttachmentPressed;

  /// Will be called on [SendButton] tap. Has [types.PartialText] which can
  /// be transformed to [types.TextMessage] and added to the messages list.
  final void Function(types.PartialText) onSendPressed;

  /// Will be called whenever the text inside [TextField] changes.
  final void Function(String)? onTextChanged;

  /// Will be called on [TextField] tap.
  final void Function()? onTextFieldTap;

  final types.TextMessage? replyingToMessage;

  /// Controls the visibility behavior of the [SendButton] based on the
  /// [TextField] state inside the [Input] widget.
  /// Defaults to [SendButtonVisibilityMode.editing].
  final SendButtonVisibilityMode sendButtonVisibilityMode;

  @override
  State<Input> createState() => _InputState();
}

/// [Input] widget state.
class _InputState extends State<Input> {
  final _inputFocusNode = FocusNode();
  bool _sendButtonVisible = false;
  late final TextEditingController _textController;
  final _mentionsKey = GlobalKey<FlutterMentionsState>();
  String _valueWithMarkup = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // get _textController after the first frame from mentions
      _textController = _mentionsKey.currentState!.controller!;
      _handleSendButtonVisibilityModeChange();
    });
  }

  @override
  void didUpdateWidget(covariant Input oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sendButtonVisibilityMode != oldWidget.sendButtonVisibilityMode) {
      _handleSendButtonVisibilityModeChange();
    }
    _inputFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return GestureDetector(
      onTap: () => _inputFocusNode.requestFocus(),
      child: isAndroid || isIOS
          ? _inputBuilder()
          : Shortcuts(
              shortcuts: {
                LogicalKeySet(LogicalKeyboardKey.enter):
                    const SendMessageIntent(),
                LogicalKeySet(LogicalKeyboardKey.enter, LogicalKeyboardKey.alt):
                    const NewLineIntent(),
                LogicalKeySet(
                  LogicalKeyboardKey.enter,
                  LogicalKeyboardKey.shift,
                ): const NewLineIntent(),
              },
              child: Actions(
                actions: {
                  SendMessageIntent: CallbackAction<SendMessageIntent>(
                    onInvoke: (SendMessageIntent intent) =>
                        _handleSendPressed(),
                  ),
                  NewLineIntent: CallbackAction<NewLineIntent>(
                    onInvoke: (NewLineIntent intent) => _handleNewLine(),
                  ),
                },
                child: _inputBuilder(),
              ),
            ),
    );
  }

  void _handleNewLine() {
    final newValue = '${_textController.text}\r\n';
    _textController.value = TextEditingValue(
      text: newValue,
      selection: TextSelection.fromPosition(
        TextPosition(offset: newValue.length),
      ),
    );
  }

  void _handleSendButtonVisibilityModeChange() {
    _textController.removeListener(_handleTextControllerChange);
    if (widget.sendButtonVisibilityMode == SendButtonVisibilityMode.hidden) {
      _sendButtonVisible = false;
    } else if (widget.sendButtonVisibilityMode ==
        SendButtonVisibilityMode.editing) {
      _sendButtonVisible = _textController.text.trim() != '';
      _textController.addListener(_handleTextControllerChange);
    } else {
      _sendButtonVisible = true;
    }
  }

  void _handleSendPressed() {
    final trimmedText = _valueWithMarkup.trim();
    if (trimmedText != '') {
      final partialText = types.PartialText(text: trimmedText);
      widget.onSendPressed(partialText);
      _textController.clear();
      _valueWithMarkup = '';
    }
  }

  void _handleTextControllerChange() {
    setState(() {
      _sendButtonVisible = _textController.text.trim() != '';
    });
  }

  Widget _inputBuilder() {
    final query = MediaQuery.of(context);
    final buttonPadding = InheritedChatTheme.of(context)
        .theme
        .inputPadding
        .copyWith(left: 16, right: 16);
    final safeAreaInsets = kIsWeb
        ? EdgeInsets.zero
        : EdgeInsets.fromLTRB(
            query.padding.left,
            0,
            query.padding.right,
            query.viewInsets.bottom + query.padding.bottom,
          );
    final textPadding = InheritedChatTheme.of(context)
        .theme
        .inputPadding
        .copyWith(left: 0, right: 0)
        .add(
          EdgeInsets.fromLTRB(
            widget.onAttachmentPressed != null ? 0 : 24,
            0,
            _sendButtonVisible ? 0 : 24,
            0,
          ),
        );

    return Padding(
      padding: InheritedChatTheme.of(context).theme.inputMargin,
      child: Material(
        borderRadius: InheritedChatTheme.of(context).theme.inputBorderRadius,
        color: InheritedChatTheme.of(context).theme.inputBackgroundColor,
        child: Container(
          decoration:
              InheritedChatTheme.of(context).theme.inputContainerDecoration,
          padding: safeAreaInsets,
          child: Column(
            children: [
              if (widget.replyingToMessage != null)
                Padding(
                  padding: InheritedChatTheme.of(context)
                      .theme
                      .inputPadding
                      .copyWith(bottom: 0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: InheritedChatTheme.of(context)
                          .theme
                          .backgroundColor,
                    ),
                    child: ReplyMessageWidget(
                      message: widget.replyingToMessage!,
                      onCancelReply: widget.onCancelReply,
                    ),
                  ),
                ),
              Row(
                textDirection: TextDirection.ltr,
                children: [
                  if (widget.onAttachmentPressed != null)
                    AttachmentButton(
                      isLoading: widget.isAttachmentUploading ?? false,
                      onPressed: widget.onAttachmentPressed,
                      padding: buttonPadding,
                    ),
                  Expanded(
                    child: Padding(
                      padding: textPadding,
                      child: FlutterMentions(
                        key: _mentionsKey,
                        suggestionPosition: SuggestionPosition.Top,
                        textCapitalization: TextCapitalization.sentences,
                        mentions: widget.mentions?.isNotEmpty == true
                            ? widget.mentions!
                            : [Mention(trigger: '@')],
                        onMarkupChanged: (val) => _valueWithMarkup = val,
                        suggestionListDecoration:
                            widget.suggestionListDecoration,
                        cursorColor: InheritedChatTheme.of(context)
                            .theme
                            .inputTextCursorColor,
                        keyboardType: TextInputType.multiline,
                        maxLines: 5,
                        minLines: 1,
                        onTap: widget.onTextFieldTap,
                        decoration: InheritedChatTheme.of(context)
                            .theme
                            .inputTextDecoration
                            .copyWith(
                              hintStyle: InheritedChatTheme.of(context)
                                  .theme
                                  .inputTextStyle
                                  .copyWith(
                                    color: InheritedChatTheme.of(context)
                                        .theme
                                        .inputTextColor
                                        .withOpacity(0.5),
                                  ),
                              hintText: InheritedL10n.of(context)
                                  .l10n
                                  .inputPlaceholder,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.white
                                  : const Color.fromARGB(255, 42, 57, 66),
                            ),
                        focusNode: _inputFocusNode,
                        onChanged: widget.onTextChanged,
                        appendSpaceOnAdd: true,
                        onSubmitted: (value) => _handleSendPressed(),
                        autofocus: true,
                        onMentionAdd: (data) {
                          // focus the text field after adding a mention
                          // because the focus gets lost
                          _inputFocusNode.requestFocus();
                        },
                        style: InheritedChatTheme.of(context)
                            .theme
                            .inputTextStyle
                            .copyWith(
                              color: InheritedChatTheme.of(context)
                                  .theme
                                  .inputTextColor,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Visibility(
                    visible: _sendButtonVisible,
                    child: SendButton(
                      onPressed: _handleSendPressed,
                      padding: buttonPadding,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReplyMessageWidget extends StatelessWidget {
  const ReplyMessageWidget({
    super.key,
    required this.message,
    this.onCancelReply,
  });

  final types.TextMessage message;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: InheritedChatTheme.of(context).theme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                ),
              ),
              width: 6,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: buildReplyMessage(),
              ),
            ),
          ],
        ),
      );

  Widget buildReplyMessage() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${message.author.firstName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (onCancelReply != null)
                InkWell(
                  onTap: onCancelReply,
                  child: const Icon(Icons.close, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message.text),
        ],
      );
}
