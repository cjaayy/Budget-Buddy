# Agent Guidelines

## Direct Edit Rules
- **No Analyzers / No Tests**: Under NO circumstances should `flutter analyze`, `dart analyze`, `flutter test`, or slow test runners be executed unless explicitly instructed by the user.
- **Fast Direct Edits**: Apply changes directly to files using file modification tools to ensure quick response times.
- **Immediate Execution / Zero Pre-Analysis**: Do NOT write plans, step-by-step reasoning, or explanations before editing. Apply file edits on turn 1 immediately.
- **Strict Single-File Focus**: Read ONLY the specific target file needed for the request. Do NOT scan directory trees or inspect unrelated files unless strictly necessary.
- **No Chat Explanations**: Do NOT explain what you did after modifying a file. Return minimal prose (1 line max) or complete the tool call and stop.
- **Direct Target Modification**: If a prompt mentions a specific screen or file, edit that file directly without checking other dependencies or re-reading the prompt rules out loud.