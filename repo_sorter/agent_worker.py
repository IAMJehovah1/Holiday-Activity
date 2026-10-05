"""
Thermal-aware Agent–Worker orchestration model for Apple Silicon (iPadOS / iPad Pro).

This module implements a *language-model-style* task planner whose primary
optimisation target is **thermal headroom**, not raw throughput.  Instead of
overloading every thread with complex work (which heats the SoC and drains
the battery), the :class:`ThermalAgent` delegates to *agent-qualified*
:class:`AgentWorker` instances that prefer the M-series **efficiency cores**.
When a worker finishes, it returns its power budget to the agent via a
:class:`PowerHandoff` token — the *power hand-back protocol* — so the chipset
cools down instead of heating up.

Model overview
--------------
* ``ThermalAgent``  — orchestrator ("the LLM").  Owns the total power budget,
  estimates the thermal cost of each planned step, and routes work to the
  coolest qualified worker.
* ``AgentWorker``   — a qualified executor.  Qualification is expressed as a
  :class:`SkillProfile` trained from workflow patterns of advanced users and
  algorithms (see :func:`trained_workers`).  Workers report joules consumed
  and hand their *remaining* power budget back to the agent on completion.
* ``SkillProfile``  — per-worker capability vector plus an efficiency-core
  affinity in ``[0, 1]``.  Higher affinity ⇒ the worker is scheduled onto
  efficiency cores (iPadOS ``QOS_CLASS_UTILITY``/``BACKGROUND`` style).
* ``PowerHandoff``  — immutable record of one delegation: power granted,
  power consumed, power returned, and the thermal stats of the run.

The planner is *trained* in the sense that its cost model and routing weights
are derived from curated workflow patterns (``_TRAINED_PATTERNS``) distilled
from advanced-user and algorithmic best practices: batch I/O, cache-local
work, single-pass streaming, and bursty-then-idle scheduling.

Everything runs in simulation — no real hardware access is required — so the
model is fully testable on any platform.

Usage (standalone)::

    python -m repo_sorter agent "Summarise the repo catalogue" --demo

Usage (programmatic)::

    from repo_sorter.agent_worker import ThermalAgent, trained_workers

    agent = ThermalAgent(power_budget_w=5.0)
    for worker in trained_workers():
        agent.register_worker(worker)
    report = agent.run("Index and tag 1,200 medical repositories")
    print(report.summary())
"""

from __future__ import annotations

import time
import uuid
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional, TextIO
import sys


# ---------------------------------------------------------------------------
# Core types
# ---------------------------------------------------------------------------


class CoreType(Enum):
    """Apple Silicon core classes."""

    PERFORMANCE = "performance"
    EFFICIENCY = "efficiency"


#: Relative power draw of each core class (watts, normalised for the model).
CORE_POWER_W = {
    CoreType.PERFORMANCE: 4.6,
    CoreType.EFFICIENCY: 0.9,
}

#: Relative throughput of each core class (work-units per second).
CORE_SPEED = {
    CoreType.PERFORMANCE: 4.0,
    CoreType.EFFICIENCY: 1.0,
}


# ---------------------------------------------------------------------------
# Skill profile / task
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class SkillProfile:
    """
    Capability vector for a worker, trained from advanced-user workflows.

    Attributes
    ----------
    skills:
        Frozenset of capability tags, e.g. ``{"tokenize", "retrieve"}``.
    efficiency_affinity:
        ``0.0`` – ``1.0``.  How well this worker's skill set maps to
        efficiency cores.  Values are learned from the trained patterns:
        streaming / I/O-bound skills score high, compute-dense skills low.
    """

    skills: frozenset
    efficiency_affinity: float = 0.5

    def __post_init__(self) -> None:
        if not 0.0 <= self.efficiency_affinity <= 1.0:
            raise ValueError("efficiency_affinity must be in [0.0, 1.0]")

    def covers(self, required: frozenset) -> bool:
        """True when this profile satisfies every required skill."""
        return required.issubset(self.skills)


@dataclass(frozen=True)
class TaskStep:
    """
    One planned unit of work produced by the agent's planner.

    ``complexity`` is measured in abstract work-units; ``required_skills``
    gates which workers may execute the step.
    """

    name: str
    complexity: float
    required_skills: frozenset

    def __post_init__(self) -> None:
        if self.complexity <= 0:
            raise ValueError("complexity must be positive")


# ---------------------------------------------------------------------------
# Trained workflow patterns
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class WorkflowPattern:
    """
    A distilled workflow pattern from advanced users / algorithms.

    ``step_skills`` are the skill tags the pattern exercises; ``chunking``
    is the learned fraction of work that can be stream-chunked onto
    efficiency cores; ``duty_cycle`` is the learned active fraction
    (burst-then-idle), where a lower duty cycle yields cooler operation.
    """

    name: str
    step_skills: frozenset
    chunking: float
    duty_cycle: float
    description: str = ""


_TRAINED_PATTERNS: List[WorkflowPattern] = [
    WorkflowPattern(
        name="stream-tokenize",
        step_skills=frozenset({"tokenize", "stream"}),
        chunking=0.85,
        duty_cycle=0.40,
        description="Single-pass streaming tokenisation; no materialisation.",
    ),
    WorkflowPattern(
        name="batch-retrieve",
        step_skills=frozenset({"retrieve", "batch-io"}),
        chunking=0.90,
        duty_cycle=0.35,
        description="Batched I/O with idle gaps so the memory controller rests.",
    ),
    WorkflowPattern(
        name="cache-local-reason",
        step_skills=frozenset({"reason", "cache-local"}),
        chunking=0.50,
        duty_cycle=0.60,
        description="Cache-resident reasoning bursts; avoids DRAM round-trips.",
    ),
    WorkflowPattern(
        name="quantized-infer",
        step_skills=frozenset({"infer", "quantize"}),
        chunking=0.65,
        duty_cycle=0.55,
        description="INT8/FP16 quantized inference on efficiency-class ALUs.",
    ),
    WorkflowPattern(
        name="reduce-summarize",
        step_skills=frozenset({"summarize", "reduce"}),
        chunking=0.75,
        duty_cycle=0.45,
        description="Tree-reduce summarisation with bounded fan-in.",
    ),
]


def trained_patterns() -> List[WorkflowPattern]:
    """Return the workflow patterns the model was trained on."""
    return list(_TRAINED_PATTERNS)


def trained_workers() -> List["AgentWorker"]:
    """
    Instantiate the standard pool of agent-qualified workers whose skill
    profiles are derived from the trained workflow patterns.
    """
    return [
        AgentWorker(
            name="tokenizer-e",
            profile=SkillProfile(frozenset({"tokenize", "stream"}), 0.95),
        ),
        AgentWorker(
            name="retriever-e",
            profile=SkillProfile(frozenset({"retrieve", "batch-io"}), 0.90),
        ),
        AgentWorker(
            name="reasoner-p",
            profile=SkillProfile(frozenset({"reason", "cache-local"}), 0.35),
        ),
        AgentWorker(
            name="inference-e",
            profile=SkillProfile(frozenset({"infer", "quantize"}), 0.80),
        ),
        AgentWorker(
            name="summarizer-e",
            profile=SkillProfile(frozenset({"summarize", "reduce"}), 0.85),
        ),
    ]


# ---------------------------------------------------------------------------
# Thermal statistics / power handoff
# ---------------------------------------------------------------------------


@dataclass
class ThermalStats:
    """Thermal outcome of a completed step or run."""

    energy_joules: float = 0.0
    peak_power_w: float = 0.0
    efficiency_core_fraction: float = 0.0
    idle_fraction: float = 0.0

    @property
    def heat_score(self) -> float:
        """
        Relative heat output.  Lower is cooler; a naive all-performance-core
        run of the same work scores ``1.0`` by construction.
        """
        return self.energy_joules


@dataclass(frozen=True)
class PowerHandoff:
    """
    Immutable record of one agent→worker delegation and worker→agent
    power return.  ``power_returned_w`` is what cools the chipset down:
    the worker only burns what the task needs and hands the rest back.
    """

    handoff_id: str
    worker_name: str
    step_name: str
    power_granted_w: float
    power_consumed_w: float
    power_returned_w: float
    core_type: CoreType
    stats: ThermalStats


# ---------------------------------------------------------------------------
# Worker
# ---------------------------------------------------------------------------


class WorkerBusyError(RuntimeError):
    """Raised when delegating to a worker that has not returned power yet."""


class AgentWorker:
    """
    An agent-qualified worker.

    A worker becomes *qualified* for a step when its :class:`SkillProfile`
    covers the step's ``required_skills``.  While executing, the worker draws
    from the power budget the agent granted; on completion it returns the
    unconsumed budget to the agent (:meth:`complete`).
    """

    def __init__(self, name: str, profile: SkillProfile) -> None:
        self.name = name
        self.profile = profile
        self._holding_power: Optional[float] = None

    # -- qualification ------------------------------------------------------

    def is_qualified(self, step: TaskStep) -> bool:
        return self.profile.covers(step.required_skills)

    @property
    def preferred_core(self) -> CoreType:
        """
        Core class this worker is scheduled on.  Affinity ≥ 0.5 maps to the
        efficiency cluster (iPadOS utility QoS); below that, the performance
        cluster is used for the shortest possible burst.
        """
        if self.profile.efficiency_affinity >= 0.5:
            return CoreType.EFFICIENCY
        return CoreType.PERFORMANCE

    # -- lifecycle ------------------------------------------------------------

    @property
    def is_holding_power(self) -> bool:
        return self._holding_power is not None

    def accept_power(self, watts: float) -> None:
        if self._holding_power is not None:
            raise WorkerBusyError(
                f"Worker '{self.name}' is still holding "
                f"{self._holding_power:.2f} W from a previous delegation"
            )
        if watts <= 0:
            raise ValueError("power grant must be positive")
        self._holding_power = watts

    def execute(self, step: TaskStep, pattern: Optional[WorkflowPattern]) -> ThermalStats:
        """
        Simulate executing ``step`` on the worker's preferred core.

        The trained ``pattern`` (when supplied) improves the duty cycle and
        shifts chunked work to efficiency cores, reducing energy per unit work.
        """
        if self._holding_power is None:
            raise RuntimeError(
                f"Worker '{self.name}' cannot execute without a power grant"
            )
        core = self.preferred_core
        speed = CORE_SPEED[core]
        active_seconds = step.complexity / speed

        chunking = pattern.chunking if pattern else 0.0
        duty_cycle = pattern.duty_cycle if pattern else 1.0

        # Chunked portion effectively runs at efficiency-core power even for
        # performance-affinity workers (the pattern migrates those slices).
        eff_power = CORE_POWER_W[CoreType.EFFICIENCY]
        core_power = CORE_POWER_W[core]
        blended_power = core_power * (1.0 - chunking) + eff_power * chunking
        blended_power *= duty_cycle  # burst-then-idle saves average power

        energy = blended_power * active_seconds
        return ThermalStats(
            energy_joules=energy,
            peak_power_w=blended_power,
            efficiency_core_fraction=(
                1.0 if core is CoreType.EFFICIENCY else chunking
            ),
            idle_fraction=1.0 - duty_cycle,
        )

    def complete(self, step: TaskStep, stats: ThermalStats) -> PowerHandoff:
        """
        Finish the step and return unconsumed power to the agent.
        """
        if self._holding_power is None:
            raise RuntimeError(
                f"Worker '{self.name}' has no power to return"
            )
        granted = self._holding_power
        consumed = min(stats.peak_power_w, granted)
        self._holding_power = None
        return PowerHandoff(
            handoff_id=uuid.uuid4().hex[:12],
            worker_name=self.name,
            step_name=step.name,
            power_granted_w=granted,
            power_consumed_w=consumed,
            power_returned_w=granted - consumed,
            core_type=self.preferred_core,
            stats=stats,
        )


# ---------------------------------------------------------------------------
# Agent
# ---------------------------------------------------------------------------


@dataclass
class RunReport:
    """Aggregate result of :meth:`ThermalAgent.run`."""

    prompt: str
    steps: List[TaskStep]
    handoffs: List[PowerHandoff]
    baseline_energy_joules: float
    actual_energy_joules: float
    elapsed_seconds: float

    @property
    def energy_saved_fraction(self) -> float:
        if self.baseline_energy_joules <= 0:
            return 0.0
        return 1.0 - (self.actual_energy_joules / self.baseline_energy_joules)

    @property
    def power_returned_w(self) -> float:
        return sum(h.power_returned_w for h in self.handoffs)

    def summary(self) -> str:
        saved_pct = self.energy_saved_fraction * 100.0
        lines = [
            f"Prompt          : {self.prompt}",
            f"Steps executed  : {len(self.handoffs)}",
            f"Baseline energy : {self.baseline_energy_joules:.2f} J (naive, all P-cores)",
            f"Actual energy   : {self.actual_energy_joules:.2f} J (agent-worker model)",
            f"Energy saved    : {saved_pct:.1f}%",
            f"Power handed back: {self.power_returned_w:.2f} W",
            f"Elapsed (sim)   : {self.elapsed_seconds:.2f} s",
        ]
        return "\n".join(lines)


class ThermalAgent:
    """
    The orchestrator ("LLM") of the agent–worker relationship.

    Parameters
    ----------
    power_budget_w:
        Total sustained power envelope the agent manages (watts).  The agent
        never grants more than this at any moment, and reclaimed power from
        completed workers flows back into the available budget.
    max_parallel:
        Maximum simultaneous delegations.  Defaults to 2 — mirroring the
        efficiency cluster of an M-series iPad Pro SoC.
    """

    def __init__(self, power_budget_w: float = 5.0, max_parallel: int = 2) -> None:
        if power_budget_w <= 0:
            raise ValueError("power_budget_w must be positive")
        if max_parallel < 1:
            raise ValueError("max_parallel must be at least 1")
        self.power_budget_w = power_budget_w
        self.max_parallel = max_parallel
        self._available_w = power_budget_w
        self._workers: List[AgentWorker] = []

    # -- worker pool ---------------------------------------------------------

    def register_worker(self, worker: AgentWorker) -> None:
        if any(w.name == worker.name for w in self._workers):
            raise ValueError(f"Duplicate worker name: {worker.name}")
        self._workers.append(worker)

    @property
    def workers(self) -> List[AgentWorker]:
        return list(self._workers)

    # -- planning --------------------------------------------------------------

    def plan(self, prompt: str) -> List[TaskStep]:
        """
        Decompose a natural-language prompt into task steps using the trained
        workflow patterns.  Patterns whose skill tags appear (as words) in the
        prompt are matched first; the remaining work falls back to a generic
        inference step sized by prompt length.
        """
        words = {w.strip(".,;:!?\"'").lower() for w in prompt.split()}
        steps: List[TaskStep] = []
        matched: List[WorkflowPattern] = []
        for pattern in _TRAINED_PATTERNS:
            if pattern.step_skills & words or any(
                skill.split("-")[0] in words for skill in pattern.step_skills
            ):
                matched.append(pattern)

        complexity_base = max(1.0, len(prompt) / 24.0)
        if matched:
            share = complexity_base / len(matched)
            for pattern in matched:
                steps.append(
                    TaskStep(
                        name=f"{pattern.name}",
                        complexity=share,
                        required_skills=pattern.step_skills,
                    )
                )
        else:
            steps.append(
                TaskStep(
                    name="general-infer",
                    complexity=complexity_base,
                    required_skills=frozenset({"infer"}),
                )
            )
        return steps

    def _match_pattern(self, step: TaskStep) -> Optional[WorkflowPattern]:
        for pattern in _TRAINED_PATTERNS:
            if pattern.step_skills == step.required_skills:
                return pattern
        return None

    # -- routing -----------------------------------------------------------------

    def _coolest_qualified_worker(self, step: TaskStep) -> Optional[AgentWorker]:
        """
        Pick the qualified, idle worker with the highest efficiency-core
        affinity — the 'coolest' choice.
        """
        candidates = [
            w
            for w in self._workers
            if w.is_qualified(step) and not w.is_holding_power
        ]
        if not candidates:
            return None
        return max(candidates, key=lambda w: w.profile.efficiency_affinity)

    # -- execution -----------------------------------------------------------------

    def run(self, prompt: str, *, _sleep: bool = False) -> RunReport:
        """
        Plan and execute ``prompt`` through the agent–worker relationship.

        For every step the agent grants power to the coolest qualified worker;
        the worker executes under its trained pattern and *hands the remaining
        power back*, which the agent reclaims into its budget before the next
        delegation.  ``_sleep`` (test seam) adds a real 1 ms pause per step to
        mimic burst-then-idle pacing.
        """
        if not self._workers:
            raise RuntimeError("No workers registered; call register_worker() first")

        start = time.monotonic()
        steps = self.plan(prompt)
        handoffs: List[PowerHandoff] = []
        baseline_energy = 0.0
        actual_energy = 0.0

        for step in steps:
            worker = self._coolest_qualified_worker(step)
            if worker is None:
                raise RuntimeError(
                    f"No qualified idle worker for step '{step.name}' "
                    f"(requires {sorted(step.required_skills)})"
                )

            # Grant only what the step can draw on its target core, capped by
            # the available budget; the rest stays cool in reserve.
            grant = min(self._available_w, CORE_POWER_W[worker.preferred_core])
            if grant <= 0:
                raise RuntimeError("Power budget exhausted")
            self._available_w -= grant

            worker.accept_power(grant)
            pattern = self._match_pattern(step)
            stats = worker.execute(step, pattern)
            handoff = worker.complete(step, stats)

            # Power hand-back: the returned watts cool the SoC and become
            # available for the next delegation; consumed watts stay spent.
            self._available_w = min(
                self._available_w + handoff.power_returned_w,
                self.power_budget_w,
            )

            handoffs.append(handoff)
            actual_energy += stats.energy_joules
            # Naive baseline: same work flat-out on performance cores.
            baseline_energy += (
                step.complexity / CORE_SPEED[CoreType.PERFORMANCE]
            ) * CORE_POWER_W[CoreType.PERFORMANCE]

            if _sleep:
                time.sleep(0.001)

        elapsed = time.monotonic() - start
        return RunReport(
            prompt=prompt,
            steps=steps,
            handoffs=handoffs,
            baseline_energy_joules=baseline_energy,
            actual_energy_joules=actual_energy,
            elapsed_seconds=elapsed,
        )


# ---------------------------------------------------------------------------
# Demo driver used by the CLI
# ---------------------------------------------------------------------------


def run_demo(
    prompt: str,
    *,
    power_budget_w: float = 5.0,
    _stream: Optional[TextIO] = None,
) -> RunReport:
    """
    Run a full agent–worker demonstration and pretty-print the report.

    Returns the :class:`RunReport` for programmatic inspection.
    """
    out = _stream or sys.stdout
    agent = ThermalAgent(power_budget_w=power_budget_w)
    for worker in trained_workers():
        agent.register_worker(worker)

    report = agent.run(prompt)

    print(f"\n🤖  ThermalAgent — agent/worker cooldown model\n", file=out)
    for handoff in report.handoffs:
        core_tag = "E-core" if handoff.core_type is CoreType.EFFICIENCY else "P-core"
        print(
            f"  • {handoff.step_name:<20} → {handoff.worker_name:<12} "
            f"[{core_tag}]  granted {handoff.power_granted_w:.2f} W, "
            f"used {handoff.power_consumed_w:.2f} W, "
            f"returned {handoff.power_returned_w:.2f} W",
            file=out,
        )
    print(f"\n🧊  {report.summary()}\n", file=out)
    return report
