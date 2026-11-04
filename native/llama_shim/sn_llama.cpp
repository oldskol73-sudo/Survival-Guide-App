// Implementation of the sn_llama C ABI over llama.cpp (written against the llama.h API of late 2026:
// llama_model_load_from_file / llama_init_from_model / llama_vocab / llama_memory_*).

#include "sn_llama.h"

#include <atomic>
#include <cstring>
#include <string>
#include <vector>

#include "llama.h"

namespace {

llama_model *g_model = nullptr;
llama_context *g_ctx = nullptr;
const llama_vocab *g_vocab = nullptr;
std::atomic<bool> g_cancel{false};
std::string g_error;
bool g_backend_ready = false;

int32_t fail(int32_t code, const std::string &msg) {
  g_error = msg;
  return code;
}

// Applies the GGUF's embedded chat template (Llama 3, Qwen 2.5, ... all ship one).
bool format_prompt(const char *system_prompt, const char *user_prompt, std::string &out) {
  const char *tmpl = llama_model_chat_template(g_model, nullptr);
  if (tmpl == nullptr) return false;
  llama_chat_message msgs[2] = {{"system", system_prompt}, {"user", user_prompt}};
  std::vector<char> buf(2 * (std::strlen(system_prompt) + std::strlen(user_prompt)) + 512);
  int32_t n = llama_chat_apply_template(tmpl, msgs, 2, true, buf.data(), (int32_t)buf.size());
  if (n < 0) return false;
  if (n > (int32_t)buf.size()) {
    buf.resize(n);
    n = llama_chat_apply_template(tmpl, msgs, 2, true, buf.data(), (int32_t)buf.size());
    if (n < 0) return false;
  }
  out.assign(buf.data(), n);
  return true;
}

bool tokenize(const std::string &text, std::vector<llama_token> &out) {
  // First call with no buffer returns -(required count).
  int32_t n = -llama_tokenize(g_vocab, text.c_str(), (int32_t)text.size(), nullptr, 0, true, true);
  if (n <= 0) return false;
  out.resize(n);
  return llama_tokenize(g_vocab, text.c_str(), (int32_t)text.size(), out.data(), n, true, true) >= 0;
}

// Length of the longest prefix of `s` that ends on a complete UTF-8 code point.
size_t complete_utf8_prefix(const std::string &s) {
  size_t i = s.size();
  size_t back = 0;
  while (i > 0 && back < 4) {
    unsigned char c = (unsigned char)s[i - 1];
    if ((c & 0xC0) != 0x80) {  // lead byte or ASCII
      size_t need = (c < 0x80) ? 1 : ((c & 0xE0) == 0xC0) ? 2 : ((c & 0xF0) == 0xE0) ? 3 : ((c & 0xF8) == 0xF0) ? 4 : 1;
      return (back + 1 >= need) ? s.size() : i - 1;
    }
    --i;
    ++back;
  }
  return s.size();
}

}  // namespace

extern "C" {

int32_t sn_llm_load(const char *model_path, int32_t n_ctx, int32_t n_threads, int32_t n_gpu_layers) {
  sn_llm_unload();
  if (!g_backend_ready) {
    llama_backend_init();
    g_backend_ready = true;
  }
  llama_model_params mp = llama_model_default_params();
  mp.n_gpu_layers = n_gpu_layers;  // iOS Metal: 99 (all); Android CPU: 0
  // Weights stay file-backed: the OS can page them out under memory pressure instead of killing us.
  // (Older llama.cpp releases spell this `mp.use_mmap = true;`.)
  mp.load_mode = LLAMA_LOAD_MODE_MMAP;
  g_model = llama_model_load_from_file(model_path, mp);
  if (g_model == nullptr) return fail(SN_ERR_LOAD, "failed to load model (missing, corrupt or out of memory)");

  llama_context_params cp = llama_context_default_params();
  cp.n_ctx = (uint32_t)n_ctx;
  cp.n_batch = 512;
  cp.n_threads = n_threads;
  cp.n_threads_batch = n_threads;
  g_ctx = llama_init_from_model(g_model, cp);
  if (g_ctx == nullptr) {
    llama_model_free(g_model);
    g_model = nullptr;
    return fail(SN_ERR_CONTEXT, "failed to create context (reduce n_ctx)");
  }
  g_vocab = llama_model_get_vocab(g_model);
  g_error.clear();
  return SN_OK;
}

int32_t sn_llm_is_loaded(void) { return g_ctx != nullptr ? 1 : 0; }

int32_t sn_llm_n_ctx(void) { return g_ctx ? (int32_t)llama_n_ctx(g_ctx) : 0; }

int32_t sn_llm_count_prompt_tokens(const char *system_prompt, const char *user_prompt) {
  if (!g_ctx) return fail(SN_ERR_NOT_LOADED, "model not loaded");
  std::string prompt;
  if (!format_prompt(system_prompt, user_prompt, prompt)) return fail(SN_ERR_TEMPLATE, "model has no usable chat template");
  std::vector<llama_token> toks;
  if (!tokenize(prompt, toks)) return fail(SN_ERR_TEMPLATE, "tokenization failed");
  return (int32_t)toks.size();
}

int32_t sn_llm_generate(const char *system_prompt, const char *user_prompt, int32_t max_new_tokens, float temperature,
                        uint32_t seed, sn_token_cb on_token) {
  if (!g_ctx) return fail(SN_ERR_NOT_LOADED, "model not loaded");
  g_cancel.store(false);

  std::string prompt;
  if (!format_prompt(system_prompt, user_prompt, prompt)) return fail(SN_ERR_TEMPLATE, "model has no usable chat template");
  std::vector<llama_token> toks;
  if (!tokenize(prompt, toks)) return fail(SN_ERR_TEMPLATE, "tokenization failed");

  const int32_t n_ctx = (int32_t)llama_n_ctx(g_ctx);
  if ((int32_t)toks.size() + max_new_tokens > n_ctx) return fail(SN_ERR_TOO_LONG, "prompt + reply exceed context");

  // Each question is independent: start from an empty KV cache.
  llama_memory_clear(llama_get_memory(g_ctx), true);

  // Prompt prefill in n_batch-sized slices.
  const int32_t n_batch = 512;
  for (size_t i = 0; i < toks.size(); i += n_batch) {
    if (g_cancel.load()) return SN_CANCELLED;
    int32_t n = (int32_t)std::min<size_t>(n_batch, toks.size() - i);
    if (llama_decode(g_ctx, llama_batch_get_one(toks.data() + i, n)) != 0) return fail(SN_ERR_DECODE, "prompt decode failed");
  }

  llama_sampler *smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
  llama_sampler_chain_add(smpl, llama_sampler_init_top_k(40));
  llama_sampler_chain_add(smpl, llama_sampler_init_min_p(0.05f, 1));
  llama_sampler_chain_add(smpl, llama_sampler_init_temp(temperature));
  llama_sampler_chain_add(smpl, llama_sampler_init_dist(seed));

  std::string pending;  // bytes not yet emitted (incomplete UTF-8 tail)
  char piece[256];
  int32_t produced = 0;
  int32_t rc = 0;

  while (produced < max_new_tokens) {
    if (g_cancel.load()) {
      rc = SN_CANCELLED;
      break;
    }
    llama_token tok = llama_sampler_sample(smpl, g_ctx, -1);
    if (llama_vocab_is_eog(g_vocab, tok)) break;

    int32_t n = llama_token_to_piece(g_vocab, tok, piece, (int32_t)sizeof(piece), 0, false);
    if (n > 0) {
      pending.append(piece, (size_t)n);
      size_t ready = complete_utf8_prefix(pending);
      if (ready > 0 && on_token) {
        on_token(pending.data(), (int32_t)ready);
        pending.erase(0, ready);
      }
    }
    ++produced;

    llama_token next = tok;
    if (llama_decode(g_ctx, llama_batch_get_one(&next, 1)) != 0) {
      rc = fail(SN_ERR_DECODE, "decode failed during generation");
      break;
    }
  }
  if (!pending.empty() && on_token) on_token(pending.data(), (int32_t)pending.size());
  llama_sampler_free(smpl);
  return rc < 0 ? rc : produced;
}

void sn_llm_cancel(void) { g_cancel.store(true); }

void sn_llm_unload(void) {
  if (g_ctx) llama_free(g_ctx);
  if (g_model) llama_model_free(g_model);
  g_ctx = nullptr;
  g_model = nullptr;
  g_vocab = nullptr;
}

const char *sn_llm_last_error(void) { return g_error.c_str(); }

}  // extern "C"
