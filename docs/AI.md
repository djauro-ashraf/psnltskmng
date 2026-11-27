# AI providers, prompt size and routing

Written 2026-11-25. The free tiers below change often: **re-check them before
relying on a number** (the links are in `lib/ai/ai_models.dart`).

## 1. Providers

Gemini stays (the free tier is refused to many accounts, and may come back).
Three more are offered; all of them need no card.

| Provider | Id | Free limits (when checked) | Key | Notes |
|---|---|---|---|---|
| Gemini | `gemini` | per Google's pricing page | aistudio.google.com | Often not available to an account (flagged, or EEA/UK/CH). |
| Groq | `groq` | gpt-oss-120b / 20b: 30 requests/min, 1,000/day, **8,000 tokens/min, 200,000 tokens/day** | console.groq.com | Llama 3.x is no longer on the free plan. The default model was `llama-3.3-70b-versatile` and is now `openai/gpt-oss-120b`. |
| GitHub Models | `github` | low models (gpt-4.1-mini, nano): 15/min, 150/day; high (gpt-4.1): 10/min, 50/day; **8,000 tokens in, 4,000 out per request** | a GitHub fine-grained token with the `models:read` permission | OpenAI-compatible. gpt-5 and o-series are for paid Copilot only. |
| OpenRouter | `openrouter` | every `:free` model: 20/min, **50/day** (1,000/day once $10 were ever bought) | openrouter.ai/keys | One key, many models. Free ids are retired without notice: the model field takes any text. Every request carries `provider.data_collection: deny`, so hosts that train on prompts are refused (what the app sends is personal). A model with only such hosts answers with an error: choose another. |

**Looked at and left out** (2026-11-25):

- **Cerebras**: its own docs say there is no renewing free tier any more, only a
  $5 trial that needs a verified payment method.
- **Mistral (La Plateforme, "Experiment")**: the free API plan is reported as removed
  or blocked for new organisations since autumn 2026, and the free plan may train on
  prompts. Not reliable enough to build on.
- **NVIDIA NIM**: free for prototyping only, with credits that run out.
- **Cloudflare Workers AI as a main provider**: free (10,000 neurons/day) but that
  is about 300,000 tokens of a big model a day, and it needs an account id as well
  as a token. It is used for the one job it is perfect for: sorting (section 4).

A provider that speaks the OpenAI chat protocol is **a spec, not a class**
(`OpenAiCompatSpec` in `lib/ai/openai_compat.dart`): add one there, add it to
`openAiCompatSpecs` in `ai_factory.dart`, add its models to `ai_models.dart` and
its entry to `aiProviderInfos`. The settings screens list `aiProviderInfos`, so
nothing else changes. The test `openai_compat_test.dart` fails if a default model
is not on its provider's list.

## 2. Why the size of a request matters

On the free plans the size of a request is not only a cost, it is a limit:

- GitHub Models refuses a request over 8,000 tokens in.
- Groq takes 8,000 tokens a minute and 200,000 a day: one 6,000-token request is
  most of a minute, and the day holds about 30 of them.

The agent used to send, with every message, its whole language (about 3,500
tokens) and a picture of the whole app (about 2,500 more). Measured (character
counts / 3.5, English and JSON; Arabic costs more):

| What is sent | tokens |
|---|---|
| The whole language (what `AgentPrompt.system` still is) | ~3,500 |
| The core alone (who the AI is, how it answers, what exists) | ~750 |
| Core + log | ~1,300 |
| Core + the commonest four (the fallback set) | ~1,700 |
| Biggest single module (the review rules) | ~1,500 |

A log request is now about 2,000 tokens with its picture of the app, against
about 6,000: three times as many requests a day, and it fits the 8,000 limit
with room.

## 3. Modules

`lib/agent/routing/agent_module.dart`. The language is a **core** that is always
sent, and **modules**, each taught only to the requests that need it:

`log`, `open`, `settings.app`, `settings.memo`, `settings.ai`, `partitions`,
`notes`, `data`, `plan`, `progress`, `help`.

A module has two halves: **what the AI is taught** (its text in
`AgentPrompt.build`) and **what the AI is shown** (`AgentModule.state`: which
parts of the picture of the app go with the message). Both are cut: a request
about the theme neither learns the review ladders nor sees the notes.

The settings are three modules, one per group (`AgentSettingGroup`). A test checks
that every setting of `AgentCatalog` is in a group, so a new setting cannot be
forgotten (one that is would still be shown, with the app group, and taught by no
one).

Prompts are built in the same order every time (core, then modules in the enum's
order), so the start of one prompt is the start of the next. A provider that caches
prompts can use that.

## 4. The router

What the AI is taught is chosen per request, cheapest way first
(`lib/agent/routing/agent_router.dart`):

1. **The conversation.** A short reply with no word of its own ("yes", "the second
   one", "نعم") is taught what the last turn was taught. Free.
2. **The rules.** Words, in English, French and Arabic, per module
   (`agent_triggers.dart`): "reviewed", "révisé", "حفظت" → log; "dark mode",
   "mode sombre" → settings.app; a piece with a number alone ("ch 5") → log and open.
   Whole words only. At most four modules. Free, and enough for the plain requests,
   which are most.
3. **A small model.** When the rules find nothing (or only a change with no
   topic: "make it shorter"), a small model is asked which modules fit. Its prompt
   is about 400 tokens and it answers `{"modules": [...]}`. It does not need to be
   wise: it sorts. What matters more than cleverness is that it **knows Arabic and
   French** (the requests are in them) and that it **does not spend the main
   provider's few requests**. So it is a chain, the first that answers sorts:
   1. **Cloudflare, Granite 4.0 micro** (`@cf/ibm-granite/granite-4.0-h-micro`),
      with a token and an account id of its own (optional, Settings → *Request
      router*). It is the cheapest model
      on Workers AI (about 1 neuron for a sort, on a free quota of 10,000 neurons
      a day: thousands of sorts). It is a 3B model whose card lists Arabic, French and
      English among 12 languages and "text classification" among its uses (IBM
      also warns that it is weaker outside English, which is why the keyword rules
      of the three languages go first and why a wrong sort can be corrected by the
      AI's own `need`). It is not asked for JSON mode (not every Workers AI model has it);
      the prompt asks for JSON and the reader copes. With either value missing it
      fails at once, with no network call.
   2. **The agent's own provider, its light model**
      (`AiProviderInfo.routerModel`): gemini-3.5-flash-lite, gpt-oss-20b,
      gpt-4.1-nano, gemma-4-26b. No new key. On Groq it has its own limits (Groq
      counts per model), so it does not spend the main model's tokens; on GitHub
      Models and OpenRouter it spends the few daily requests, which is the case for
      the Cloudflare key.
4. **The way back.** The AI is told which modules it was *not* taught. If it needs
   one it answers `{"need": ["settings.ai"]}`; the app adds it and asks once more
   (never twice). A wrong route costs one extra request, not a failed one.

**Nothing in this chain can fail the request.** No small model, a timeout, a rate
limit, an answer that is not JSON: the next sorter is tried (6 seconds each at most),
then the rules' own result stands, or the fallback set (log, open, progress,
settings.app).

### The three modes (Settings → Agent → "What the AI is taught")

- **Everything**: the whole language, as before. For comparing, or if routing
  ever misbehaves.
- **By words**: steps 1, 2 and 4. No extra request.
- **Smart** (default): steps 1 to 4. One more, tiny, request for the few requests
  the words cannot place. Choose *By words* on a provider with few requests a day
  (OpenRouter 50, GitHub 50 to 150).

Every answer shows a line: what was taught, how it was chosen, about how many
tokens: `Taught: log, open · by words · ≈ 1.3K tokens`. Use it to see the routing
work and to tune the triggers.

### The dedicated sorter (optional): Settings → Request router

The router has a card of its own, apart from the agent's, so that its setup is not
taken for part of the agent's key. In it: the way of sorting (Everything / By words /
Smart), and, in Smart, the dedicated sorter:

1. Free account at dash.cloudflare.com (no card).
2. Workers AI → *Use REST API*: it shows the **Account ID** and creates an **API
   token** with the *Workers AI* permission.
3. Paste each into its own field (*Cloudflare account ID*, *Cloudflare API token*)
   and *Save key*. They are kept in the secure store as `agent_cloudflare_account`
   and `agent_cloudflare`, apart from every other key. The account id may have only
   letters and digits (it is part of the address) and is checked on saving.
4. *Test* sorts a sample request with the saved values and says what happened: the
   modules it chose and the time it took, or why it failed (never the key).

The card says in words where things stand: *Not set* / *Only one of the two is saved*
/ *Ready*. **Empty, half filled, or failing, the agent's own provider sorts
instead**, and if that fails too the words of the request decide: the dedicated sorter
can only make things better, never break them.

The free quota resets daily at 00:00 UTC; past it the call fails and the next sorter
is used. Check the price table (neurons per million tokens) and the model id when
you set up: Workers AI changes its list often.

### Why not something else

- **Only a model to route.** Costs a request on every message, and on the plans
  with a daily request limit that is a real price. The rules are free and right
  most of the time; the model is for the rest.
- **Only keywords.** Cannot place "make it shorter". Hence the model.
- **Embeddings.** Needs an embedding API (another key, another quota) or a model
  on the device: more to carry than a 400-token prompt.
- **One big prompt and prompt caching.** The free plans count the tokens whether
  or not they are cached, and GitHub's 8,000-token cap is on the request.
- **Native function calling.** The tool definitions are the same weight as the
  prompt they replace, and the providers' free models differ in how they do it.

## 5. Where the rest of the AI features stand

Ask (the assistant) and the planner already send one small prompt each, shaped by
their own context (the ayah, the tafsir), so they have nothing to route. The
agent is where the tokens were. If another feature grows a large prompt, the same
pieces apply: modules with a text and a state, and a router with a way back.

## 6. When you add something

- **A setting**: add it to `AgentCatalog` **and to `AgentSettingGroup`**
  (`agent_module.dart`). `agent_router_test.dart` fails until it is in a group.
- **An instruction the AI can write**: its text goes in the module that owns it in
  `AgentPrompt`; if it needs a new part of the app's picture, add an `AgentState`.
  `agent_modules_test.dart` checks that each module teaches its own instruction
  and no other.
- **A module**: add it to `AgentModule` (id, one line of what it teaches, its
  state), its text to `AgentPrompt.build`, its words to `AgentTriggers`. The small
  model reads the one-liner, so write it as if telling someone who has not seen the
  app.
- **Triggers**: they are a list of words per module. Missing a word costs the
  small model's request (or one `need`), not a wrong answer. A word that is too
  common costs tokens on requests that did not need the module: prefer the longer
  phrase.
