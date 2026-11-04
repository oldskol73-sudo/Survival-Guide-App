// sn_llama: a deliberately tiny, stable C ABI over llama.cpp for dart:ffi.
// llama.cpp's own API changes often; only this file and sn_llama.cpp need touching when it does.
// One model + one context per process. Not re-entrant: call from a single worker thread,
// except sn_llm_cancel(), which is safe from any thread.

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define SN_API __declspec(dllexport)
#else
#define SN_API __attribute__((visibility("default"))) __attribute__((used))
#endif

// Streaming callback. `piece` is always complete UTF-8 (never a split multi-byte character),
// not NUL-terminated; `len` bytes are valid only during the call.
typedef void (*sn_token_cb)(const char *piece, int32_t len);

// Error codes
#define SN_OK 0
#define SN_ERR_NOT_LOADED -1
#define SN_ERR_LOAD -2
#define SN_ERR_CONTEXT -3
#define SN_ERR_TOO_LONG -4
#define SN_ERR_TEMPLATE -5
#define SN_ERR_DECODE -6
#define SN_CANCELLED -7

SN_API int32_t sn_llm_load(const char *model_path, int32_t n_ctx, int32_t n_threads, int32_t n_gpu_layers);
SN_API int32_t sn_llm_is_loaded(void);
SN_API int32_t sn_llm_n_ctx(void);

// Formats system + user with the model's own chat template and returns the token count (negative = error).
SN_API int32_t sn_llm_count_prompt_tokens(const char *system_prompt, const char *user_prompt);

// Generates a reply. Returns the number of tokens produced, or a negative SN_* code.
SN_API int32_t sn_llm_generate(const char *system_prompt, const char *user_prompt, int32_t max_new_tokens,
                               float temperature, uint32_t seed, sn_token_cb on_token);

SN_API void sn_llm_cancel(void);
SN_API void sn_llm_unload(void);
SN_API const char *sn_llm_last_error(void);

#ifdef __cplusplus
}
#endif
