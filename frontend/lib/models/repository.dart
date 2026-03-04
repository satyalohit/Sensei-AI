class Repository {
  final String url;
  final String? localPath;
  final String? branch;
  final List<String> setupSteps;
  final bool isAnalyzed;
  final List<Prerequisite> prerequisites;
  final String description;

  Repository({
    required this.url,
    this.localPath,
    this.branch,
    this.setupSteps = const [],
    this.isAnalyzed = false,
    this.prerequisites = const [],
    this.description = '',
  });

  factory Repository.fromJson(Map<String, dynamic> json) {
    return Repository(
      url: json['url'],
      localPath: json['localPath'],
      branch: json['branch'],
      setupSteps: json['setupSteps'] != null
          ? List<String>.from(json['setupSteps'])
          : [],
      isAnalyzed: json['isAnalyzed'] ?? false,
      prerequisites: json['prerequisites'] != null
          ? List<Prerequisite>.from(
              (json['prerequisites'] as List).map((x) => Prerequisite.fromJson(x)))
          : [],
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      if (localPath != null) 'localPath': localPath,
      if (branch != null) 'branch': branch,
      'setupSteps': setupSteps,
      'isAnalyzed': isAnalyzed,
      'prerequisites': prerequisites.map((x) => x.toJson()).toList(),
      'description': description,
    };
  }

  Repository copyWith({
    String? url,
    String? localPath,
    String? branch,
    List<String>? setupSteps,
    bool? isAnalyzed,
    List<Prerequisite>? prerequisites,
    String? description,
  }) {
    return Repository(
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      branch: branch ?? this.branch,
      setupSteps: setupSteps ?? this.setupSteps,
      isAnalyzed: isAnalyzed ?? this.isAnalyzed,
      prerequisites: prerequisites ?? this.prerequisites,
      description: description ?? this.description,
    );
  }
}

class Prerequisite {
  final String name;
  final String description;
  final String? installCommand;
  final bool isInstalled;

  Prerequisite({
    required this.name, 
    required this.description, 
    this.installCommand,
    this.isInstalled = false,
  });

  factory Prerequisite.fromJson(Map<String, dynamic> json) {
    return Prerequisite(
      name: json['name'],
      description: json['description'],
      installCommand: json['installCommand'],
      isInstalled: json['isInstalled'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      if (installCommand != null) 'installCommand': installCommand,
      'isInstalled': isInstalled,
    };
  }

  Prerequisite copyWith({
    String? name,
    String? description,
    String? installCommand,
    bool? isInstalled,
  }) {
    return Prerequisite(
      name: name ?? this.name,
      description: description ?? this.description,
      installCommand: installCommand ?? this.installCommand,
      isInstalled: isInstalled ?? this.isInstalled,
    );
  }
}
