class ModelInfo {
  final String id;
  final String name;
  final String description;
  final String url;
  final int sizeBytes;
  final String ramRequirement;
  final String speed;
  final String fileName;

  ModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.sizeBytes,
    required this.ramRequirement,
    required this.speed,
    required this.fileName,
  });

  String get sizeFormatted {
    final sizeMB = sizeBytes / (1024 * 1024);
    if (sizeMB < 1024) {
      return '${sizeMB.toStringAsFixed(0)} MB';
    }
    final sizeGB = sizeMB / 1024;
    return '${sizeGB.toStringAsFixed(1)} GB';
  }
}

// Model Catalog
final List<ModelInfo> modelCatalog = [
  ModelInfo(
    id: 'smollm2-360m',
    name: 'SmolLM2 360M',
    description: 'Ultra-fast, minimal RAM usage. Best for quick responses.',
    url: 'https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf?download=true',
    fileName: 'smollm2-360m.gguf',
    sizeBytes: 209715200, // 200MB
    ramRequirement: '1GB',
    speed: 'Very Fast',
  ),
  ModelInfo(
    id: 'qwen2-500m',
    name: 'Qwen2 500M',
    description: 'Balanced speed and quality. Good for general chat.',
    url: 'https://huggingface.co/Qwen/Qwen2-0.5B-Instruct-GGUF/resolve/main/qwen2-0_5b-instruct-q4_k_m.gguf?download=true',
    fileName: 'qwen2-500m.gguf',
    sizeBytes: 314572800, // 300MB
    ramRequirement: '1.5GB',
    speed: 'Fast',
  ),
  ModelInfo(
    id: 'tinyllama-1.1b',
    name: 'TinyLlama 1.1B',
    description: 'Compact yet capable. Great for longer conversations.',
    url: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf?download=true',
    fileName: 'tinyllama-1.1b.gguf',
    sizeBytes: 669515776, // 638MB
    ramRequirement: '2GB',
    speed: 'Medium',
  ),
  ModelInfo(
    id: 'phi-2-1.3b',
    name: 'Phi-2 1.3B',
    description: 'High quality reasoning. Best for complex tasks.',
    url: 'https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf?download=true',
    fileName: 'phi-2-1.3b.gguf',
    sizeBytes: 838860800, // 800MB
    ramRequirement: '2.5GB',
    speed: 'Medium',
  ),
  ModelInfo(
    id: 'smollm2-1.7b',
    name: 'SmolLM2 1.7B',
    description: 'Larger SmolLM variant. Better quality, slower speed.',
    url: 'https://huggingface.co/bartowski/SmolLM2-1.7B-Instruct-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Q4_K_M.gguf?download=true',
    fileName: 'smollm2-1.7b.gguf',
    sizeBytes: 1073741824, // 1GB
    ramRequirement: '3GB',
    speed: 'Slow',
  ),
];
