# PAT2PRISM — PAT to PRISM Converter

## Overview
PAT2PRISM is an engineerable and theory-backed converter that transforms high-level PAT (Process Analysis Toolkit) protocol specifications into PRISM models for formal verification. The tool is designed for researchers and engineers conducting probabilistic and adversarial analysis of communication protocols. It emphasizes correctness, reproducibility, and usability by combining a formal IR, parameterized templates, and a web-based interface.

## Table of Contents
- Features
- Installation
- Quick Start (CLI and Web UI)
- Usage Examples
- Architecture
- Reproducibility and Experiments
- Screenshots
- Case study in paper
- Contributing
- License & Contact

## Key Features
- **Correct and Parameterized Transformation**: Produces PRISM models that preserve the operational semantics of the input PAT specification. Templates are parameterized to support DTMC/MDP variants and adjustable attacker/channel parameters.
- **MDP-First Semantics**: By default the generator emits PRISM MDP models to encode nondeterministic choices; templates can be configured to produce DTMCs where appropriate.
- **Automated IR and Template Pipeline**: A clean IR separates parsing from generation; Jinja2 templates render model code for PRISM, enabling auditors to inspect and adapt model generation rules.
- **Web UI for Rapid Iteration**: A lightweight Flask web UI enables online editing, quick conversion, visualization of statistics, and one-click export of generated models.
- **Message & Type Inference**: Automatic extraction of message encodings and heuristic type classification for nonces, IDs, booleans, and keys, reducing manual modeling errors.

## Installation
Prerequisites:
- Python 3.8 or newer
- Java (for PRISM) if you plan to run PRISM locally

Install Python dependencies:
```powershell
python -m pip install -r requirements.txt
```

Optional: download PRISM (recommended version used in experiments: 4.9) and add it to your PATH.

## Quick Start

Command-line conversion (example):
```powershell
# Convert a PAT file to a PRISM model
PYTHONPATH=pat2prism python -m src.pat2prism.cli -i examples/Lo_coap_eap.pat -o out/Lo_coap_eap.pm
```

Run the Web UI for interactive editing and conversion:
```powershell
cd webui
python app.py
Visit http://localhost:5000
```

## Usage Examples
- Examples are provided in `examples/`. Each example demonstrates how to map PAT constructs (prefixing, external/internal choice, parallel composition) to PRISM templates.
- The generator defaults to `mdp` semantics to preserve nondeterminism; to emit a `dtmc` model, set the template option `opts.model_type='dtmc'` or post-process the generated file.

## Architecture 

### System Overview

The conversion pipeline follows these stages:

1. Lexing (ANTLR-generated lexer)
2. Parsing (ANTLR-generated parser)
3. AST construction (visitor-based AST builder)
4. IR construction (process-centric intermediate representation)
5. PRISM rendering (Jinja2 templates)

Input: PAT specification (*.pat)
Output: PRISM model file (*.prism) — default semantics: MDP

### Core Components

- `src/pat2prism/pat_visitor.py` — AST visitor and IR builder
- `src/pat2prism/ir.py` — IR definitions (Spec, ProcessModule, Transition)
- `src/pat2prism/prism_generator_v2.py` — Template renderer that populates `prism_model.jinja2`
- `src/pat2prism/templates/prism_model.jinja2` — PRISM model template (defaults to `mdp` header)
- `webui/` — Flask-based interactive frontend
- `tools/` — Batch scripts for experiments and example conversions

### Data Model

IR captures:
- Processes as modules (states, transitions)
- Channels as global variables with integer-encoded messages
- Guards and updates as literal expressions to be refined manually when needed

### Design Rationale

- Separation of concerns enables auditable, testable transformation steps.
- Templates are parameterized to allow `mdp` vs `dtmc` output and to inject configurable attack/channel parameters.
- Manual refinement is preserved where domain knowledge is essential (crypto semantics, attack models).

### Testing Strategy

Unit tests for AST→IR and IR→template stages; integration tests validate that generated PRISM files contain expected module counts and labels.

### How to Extend

- Add new AST node handlers in `pat_visitor.py` and map them to IR constructs.
- Create or modify Jinja2 templates for alternative PRISM encodings (DTMC, CTMC, or POMDP).

## Reproducibility and Experiments
We provide a reproducible experiment pipeline used for the paper evaluation. Key artifacts are available under `paper/` and `experiment_results/`:
- `paper/*.pm` — canonical PRISM models (MDP/DTMC variants)
- `paper/prism_props_*.pctl` — property files used for verification
- `paper/result_*.txt` — PRISM run logs (model-checking outputs)
- `paper/plot_results.py`, `paper/plot_results_v2.py` — plotting scripts used to create figures

To reproduce a parameter sweep (example: varying implementation vulnerability probability `p_vuln`):
1. Edit the model parameter in the PRISM model or create temporary model copies with different parameter values.
2. Run PRISM with the appropriate properties file and redirect stdout to an output file:
```powershell
# Example: run PRISM on one model variant
prism paper/lo_coap_eap_v0_02.pm paper/prism_props_mdp.pctl > paper/result_lo_v0_02.txt
```
3. Extract `Result:` or `Value in the initial state:` lines from PRISM outputs and aggregate into CSV or use provided plotting scripts.

Automation note: `tools/` contains helper scripts for batch execution. If PRISM is not available locally, consider using the provided Docker/CI configuration to run experiments reproducibly.

## Screenshots and Figures

- Web UI: model editor and statistics
   ![Web UI placeholder](experiment_results/docs/screenshots/webui_editor.png)

- Example: generated PRISM model preview
   ![Model preview placeholder](experiment_results/docs/screenshots/model_preview.png)
## Case Study: CoAP-EAP vs. Lo-CoAP-EAP

This section presents a case study from our paper demonstrating the PAT2PRISM tool's application in analyzing two protocol variants: CoAP-EAP and Lo-CoAP-EAP. These protocols model EAP authentication over CoAP, with Lo-CoAP-EAP incorporating additional low-power optimizations. The study evaluates security properties under adversarial conditions using probabilistic model checking.

### Protocol Overview
For detailed protocol specifications, message flows, and state machines, refer to the PDF document: [CoAP-EAP vs. Lo-CoAP-EAP Protocol Details](coap-eap vs. lo_coap_eap.pdf). This document includes:
- High-level protocol descriptions for both variants.
- Message sequence diagrams.
- State transition graphs.
- Key differences between standard CoAP-EAP and the low-power optimized Lo-CoAP-EAP.

### Experimental Steps
The case study follows a reproducible pipeline to convert PAT specifications to PRISM models and perform model-checking analysis:

1. **PAT Specification Preparation**:
   - Start with PAT files: `examples/coap_eap.pat` and `examples/Lo_coap_eap.pat`.
   - These files encode the protocol logic using PAT's process algebra constructs (parallel composition, choices, guards).

2. **Tool Conversion to PRISM**:
   - Use the PAT2PRISM CLI to generate MDP models:
     ```powershell
     PYTHONPATH=pat2prism python -m src.pat2prism.cli -i examples/coap_eap.pat -o paper/coap_eap.pm
     PYTHONPATH=pat2prism python -m src.pat2prism.cli -i examples/Lo_coap_eap.pat -o paper/lo_coap_eap.pm
     ```
   - The tool automatically infers message types, applies transformation rules (R1–R11), and produces parameterized MDP models with adjustable probabilities (e.g., attacker success rates, channel losses).

3. **Model Refinement**:
   - Manually refine generated models for specific parameters (e.g., vulnerability probability `p_vuln` ranging from 0.0 to 0.1).
   - Create variants like `lo_coap_eap_v0_02.pm` for parameter sweeps.

4. **Property Specification**:
   - Define PCTL properties in `paper/prism_props_mdp.pctl`, including:
     - Pmax=? [ F "success" ] (maximum success probability).
     - Rmax=? [ C<=deadline ] (maximum reward for timely completion).
     - Adversarial properties evaluating attack impacts.

5. **Model Checking Execution**:
   - Run PRISM on model variants:
     ```powershell
     prism paper/coap_eap.pm paper/prism_props_mdp.pctl > paper/result_std.txt
     prism paper/lo_coap_eap_v0_02.pm paper/prism_props_mdp.pctl > paper/result_lo_v0_02.txt
     ```
   - Capture outputs for success rates, risk values, and reward metrics.

6. **Result Analysis and Plotting**:
   - Aggregate results from multiple runs.
   - Use `paper/plot_results.py` to generate comparative plots (e.g., success vs. vulnerability probability).
   - Visualize differences between CoAP-EAP and Lo-CoAP-EAP under varying attack conditions.

### Results and Findings
The experimental results, detailed in [CoAP-EAP vs. Lo-CoAP-EAP Protocol Details](coap-eap vs. lo_coap_eap.pdf), demonstrate:
- **Success Rates**: CoAP-EAP achieves higher success probabilities (e.g., 0.7273 baseline) compared to Lo-CoAP-EAP (e.g., 0.7672 with optimizations), but both degrade under increased vulnerability.
- **Risk Assessment**: Risk values (e.g., [0.0, 0.0075, 0.0160, 0.0285, 0.0450, 0.0650] for Lo-CoAP-EAP) quantify adversarial impacts, showing Lo-CoAP-EAP's resilience to low-power constraints.
- **Comparative Analysis**: Plots reveal trade-offs between energy efficiency and security, with Lo-CoAP-EAP maintaining acceptable performance up to p_vuln=0.06.
- **Key Insights**: MDP semantics enable precise modeling of nondeterministic attacker choices, providing more convincing results for reviewer scrutiny than DTMC-only approaches.

All raw PRISM outputs and derived result files (e.g., `paper/result_std.txt`, `paper/result_lo_*.txt`) are included for reproducibility. Reviewers can rerun experiments using the provided scripts and models.

## Contributing
- Fork the repository and open a pull request with a clear description of changes.
- Follow the code style and include tests for generator rule changes. See `CONTRIBUTING.md` if provided.

## License & Contact
- This project is released under the MIT License — see `LICENSE`.
- For questions regarding reproducibility or access to experimental artifacts, contact the authors via their institutional emails or open an issue on GitHub.




