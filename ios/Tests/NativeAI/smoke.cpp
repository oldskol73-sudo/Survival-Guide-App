// Host-side contract check; link with the pinned llama XCFramework's macOS slice.
#include "../../../native/llama_shim/sn_llama.h"
#include <cassert>
#include <cstring>
#include <dlfcn.h>
#include <initializer_list>

int main() {
    // Dart resolves these names dynamically rather than linking to them directly.
    for (const char *name : {"sn_llm_load", "sn_llm_is_loaded", "sn_llm_n_ctx",
            "sn_llm_count_prompt_tokens", "sn_llm_generate", "sn_llm_cancel",
            "sn_llm_unload", "sn_llm_last_error"}) {
        assert(dlsym(RTLD_DEFAULT, name) != nullptr);
    }
    sn_llm_unload();
    assert(sn_llm_is_loaded() == 0);
    assert(sn_llm_n_ctx() == 0);
    assert(sn_llm_count_prompt_tokens("system", "question") == SN_ERR_NOT_LOADED);
    assert(sn_llm_generate("system", "question", 8, 0.2f, 1, nullptr) == SN_ERR_NOT_LOADED);
    assert(sn_llm_load("/nonexistent/blackout-ai-test.gguf", 512, 1, 0) == SN_ERR_LOAD);
    assert(std::strlen(sn_llm_last_error()) > 0);
    assert(sn_llm_is_loaded() == 0);
    sn_llm_cancel();
    sn_llm_unload();
    sn_llm_unload();
}
