class CommandResult {
  final String command;
  final String args;
  final int exitCode;
  final String output;
  final String? error;
  final String startTime;
  final String endTime;
  final String duration;

  CommandResult({
    required this.command,
    required this.args,
    required this.exitCode,
    required this.output,
    this.error,
    required this.startTime,
    required this.endTime,
    required this.duration,
  });

  factory CommandResult.fromJson(Map<String, dynamic> json) {
    return CommandResult(
      command: json['command'],
      args: json['args'],
      exitCode: json['exitCode'],
      output: json['output'],
      error: json['error'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      duration: json['duration'],
    );
  }

  bool get isSuccess => exitCode == 0;

  String get fullCommand => '$command $args'.trim();

  @override
  String toString() {
    return 'CommandResult{command: $command, exitCode: $exitCode, duration: $duration}';
  }
}
