class ModelInfo {
  final String id;
  final String name;
  final String description;
  final String url;
  final int sizeBytes;
  final String ramRequirement;
  final String speed;
  final String fileName;
  final String family;
  final bool hasThinking;

  ModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.sizeBytes,
    required this.ramRequirement,
    required this.speed,
    required this.fileName,
    this.family = 'Other',
    this.hasThinking = false,
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

// Model Catalog — sorted by size ascending
final List<ModelInfo> modelCatalog = [
  // ==================== TINY (< 500MB) ====================
  ModelInfo(
    id: 'smollm2-135m',
    name: 'SmolLM2 135M',
    description: 'Smallest model. Near-instant replies, basic quality.',
    url: 'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/main/SmolLM2-135M-Instruct-Q4_K_M.gguf?download=true',
    fileName: 'smollm2-135m.gguf',
    sizeBytes: 104857600, // ~100MB
    ramRequirement: '512MB',
    speed: 'Instant',
    family: 'SmolLM',
  ),
  ModelInfo(
    id: 'smollm2-360m',
    name: 'SmolLM2 360M',
    description: 'Ultra-fast, minimal RAM usage. Best for quick responses.',
    url: 'https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf?download=true',
    fileName: 'smollm2-360m.gguf',
    sizeBytes: 209715200, // 200MB
    ramRequirement: '1GB',
    speed: 'Very Fast',
    family: 'SmolLM',
  ),
  ModelInfo(
    id: 'qwen2.5-0.5b',
    name: 'Qwen2.5 0.5B',
    description: 'Balanced speed and quality. Good for general chat.',
    url: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf?download=true',
    fileName: 'qwen2.5-0.5b.gguf',
    sizeBytes: 386547056, // ~369MB
    ramRequirement: '1.5GB',
    speed: 'Fast',
    family: 'Qwen',
  ),
  // NOTE: Qwen3 0.6B removed — requires llama.cpp >= b5092 (Qwen3 arch, released Apr 2025).
  // The current fllama package (v0.0.1) bundles llama.cpp from ~Nov 2024, which predates Qwen3.
  // To re-add Qwen3, switch to a newer LLM backend like llm_llamacpp (v0.1.7+).

  // ==================== SMALL (500MB - 1GB) ====================
  ModelInfo(
    id: 'tinyllama-1.1b',
    name: 'TinyLlama 1.1B',
    description: 'Compact yet capable. Great for longer conversations.',
    url: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf?download=true',
    fileName: 'tinyllama-1.1b.gguf',
    sizeBytes: 669515776, // 638MB
    ramRequirement: '2GB',
    speed: 'Medium',
    family: 'Llama',
  ),
  ModelInfo(
    id: 'smollm2-1.7b',
    name: 'SmolLM2 1.7B',
    description: 'Larger SmolLM variant. Better quality, good balance.',
    url: 'https://huggingface.co/bartowski/SmolLM2-1.7B-Instruct-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Q4_K_M.gguf?download=true',
    fileName: 'smollm2-1.7b.gguf',
    sizeBytes: 1073741824, // 1GB
    ramRequirement: '3GB',
    speed: 'Medium',
    family: 'SmolLM',
  ),

  // ==================== MEDIUM (1-2GB) ====================
  ModelInfo(
    id: 'gemma-2-2b',
    name: 'Gemma 2 2B',
    description: 'Google\'s compact model. Excellent reasoning for its size.',
    url: 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf?download=true',
    fileName: 'gemma-2-2b.gguf',
    sizeBytes: 1610612736, // ~1.5GB
    ramRequirement: '3GB',
    speed: 'Medium',
    family: 'Gemma',
  ),
  ModelInfo(
    id: 'qwen2.5-1.5b',
    name: 'Qwen2.5 1.5B',
    description: 'Strong multilingual model. Great for diverse languages.',
    url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf?download=true',
    fileName: 'qwen2.5-1.5b.gguf',
    sizeBytes: 1073741824, // ~1GB
    ramRequirement: '3GB',
    speed: 'Medium',
    family: 'Qwen',
  ),
  ModelInfo(
    id: 'stablelm-zephyr-3b',
    name: 'StableLM Zephyr 3B',
    description: 'Stability AI\'s chat model. Strong instruction following.',
    url: 'https://huggingface.co/TheBloke/stablelm-zephyr-3b-GGUF/resolve/main/stablelm-zephyr-3b.Q4_K_M.gguf?download=true',
    fileName: 'stablelm-zephyr-3b.gguf',
    sizeBytes: 1887436800, // ~1.8GB
    ramRequirement: '4GB',
    speed: 'Slow',
    family: 'StableLM',
  ),
  ModelInfo(
    id: 'phi-3.5-mini',
    name: 'Phi 3.5 Mini 3.8B',
    description: 'Microsoft\'s best small model. Top reasoning quality.',
    url: 'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf?download=true',
    fileName: 'phi-3.5-mini.gguf',
    sizeBytes: 2362232012, // ~2.2GB
    ramRequirement: '4GB',
    speed: 'Slow',
    family: 'Phi',
  ),
  ModelInfo(
    id: 'llama-3.2-3b',
    name: 'Llama 3.2 3B',
    description: 'Meta\'s latest compact Llama. Best overall quality.',
    url: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf?download=true',
    fileName: 'llama-3.2-3b.gguf',
    sizeBytes: 2147483648, // ~2GB
    ramRequirement: '4GB',
    speed: 'Slow',
    family: 'Llama',
  ),
];
