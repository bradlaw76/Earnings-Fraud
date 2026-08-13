import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  Clock3,
  Contrast,
  ListChecks,
  Menu,
  Minus,
  Pause,
  Play,
  Plus,
  RotateCcw,
  ShieldCheck,
  SkipForward,
  X,
} from "lucide-react";

const STORAGE_KEY = "ssa-earnings-integrity-presenter-v1";
const TARGET_SECONDS = 40 * 60;

const sections = [
  {
    id: "setup",
    number: "00",
    title: "Pre-Demo Setup",
    minutes: 0,
    purpose: "Confirm the live environment and every fallback before the audience joins.",
    actions: [
      "Open Earnings Integrity V2 Demo App.",
      "Confirm Earnings Integrity - Analyst Dashboard and the Earnings Integrity program dashboard load.",
      "Pre-open EIR-2025-0041 in a second browser tab.",
      "Confirm Enhanced full case form - Earnings Fraud is active.",
      "Verify Summary, Risk & Confidence, Evidence & Workflow, Workbench, AI Insights, and Review tabs.",
      "Confirm Analyst Case Workbench, Fraud AI Insights, and Supervisor Case Brief render.",
      "Confirm SSA Agent Support, Linked Agents (3), and the SSA Agent Fraud Support page load.",
      "Keep Process Events available as an optional drill-down.",
      "Do not run live AI analysis unless the HTTP trigger was prevalidated.",
    ],
    notes: [
      "Use EIR-2025-0041 as the hero case throughout the story.",
      "Describe EIR-2025-0033 only according to the status shown live.",
      "All people, amounts, records, and events are fictional demonstration data.",
    ],
    callout: "Start with the application ready, but do not begin inside the hero case.",
  },
  {
    id: "opening",
    number: "01",
    title: "Opening and Positioning",
    minutes: 2,
    purpose: "Frame the solution as one configurable example, not a prescribed SSA process.",
    actions: [
      "Begin at the top of Earnings Integrity - Analyst Dashboard with the analyst banner, filters, and KPI row visible.",
      "Leave filters at their defaults and keep My Investigations in its prepared state.",
      "Do not open Hargrove or any other record during the positioning statement.",
      "At the transition, move visual focus to the analyst identity banner without clicking.",
    ],
    notes: [
      "Today I will walk through an earnings integrity case review experience that I built in Dynamics 365 Customer Service and Dataverse.",
      "This is intentionally a concrete demonstration, not a claim that I have modeled SSA's final process.",
      "Please focus on the pattern: structured work, connected evidence, guided review, human decisions, and measurable outcomes.",
    ],
    callout: "One working configuration makes the platform tangible; SSA discovery defines the operating model.",
    transition: "I will begin with the analyst's workload, zoom out to program oversight, and then follow one case from beginning to end.",
  },
  {
    id: "agent-dashboard",
    number: "02",
    title: "Earnings Integrity - Analyst Dashboard",
    minutes: 2,
    purpose: "Show the analyst's connected workload command center across cases, discrepancies, evidence, findings, and tasks.",
    actions: [
      "Open Earnings Integrity - Analyst Dashboard.",
      "Point to analyst identity, role, operational context, refresh, and updated time.",
      "Show Search, Case Age, Risk Level, Review Phase, Evidence Status, and Review Type filters.",
      "Scan all eight KPIs from Active Investigations through Open Exposure.",
      "Expand My Investigations; identify the Hargrove link but leave it unopened for Step 04.",
      "Point to Discrepancies, Evidence, Findings, Open Tasks, and Recent Case Activity sections.",
    ],
    notes: [
      "This new web resource answers what work is active, what needs attention first, and which related evidence, findings, approvals, or tasks require action.",
      "The filters and KPIs summarize connected operational records; SSA could align the dimensions to its approved workload model.",
      "Expandable sections organize work by analyst need, while linked rows open the underlying Dataverse records when embedded in Dynamics.",
      "The dashboard is a focused entry point, not a separate system of record.",
    ],
    callout: "The dashboard brings connected case work to the analyst and keeps every summary traceable to the underlying Dataverse record.",
    status: "Demonstrated: Dataverse workload assembly, filters, KPIs, connected work sections, and record navigation. Direct-file mode uses fictional preview data; SSA routing and access scope require configuration.",
  },
  {
    id: "program-dashboard",
    number: "03",
    title: "Earnings Integrity Program Dashboard",
    minutes: 2,
    purpose: "Move from individual workload to program-level operational oversight.",
    actions: [
      "Open Earnings Integrity under Dashboards.",
      "Point to open cases, pending approval, high/critical risk, exposure, resolved, and total case KPIs.",
      "Show Cases by Risk Rating and Cases by Disposition.",
      "Scan All Cases - Detail: risk, status, exposure, approval, and review type.",
    ],
    notes: [
      "Leaders can see workload, pending approvals, risk concentration, estimated exposure, and disposition patterns without requesting a separate status report.",
      "The numbers reflect fictional data loaded in this environment. They are not SSA production measures or proposed performance targets.",
      "SSA could configure timeliness, aging, workload by office, evidence wait time, rework, supervisory returns, or approved quality measures.",
    ],
    callout: "The dashboard is a management view over the operational records, not a parallel reporting system.",
    transition: "Now I will move from the portfolio into the specific case that drives today's story.",
  },
  {
    id: "case-selection",
    number: "04",
    title: "Workload and Hero Case Selection",
    minutes: 2,
    purpose: "Explain intake, scale, and scenario variety before opening the hero case.",
    actions: [
      "Open Cases and remain in the Active/My Cases view while explaining how the view organizes the analyst's workload.",
      "Point out several EIR-2026 bulk cases to show volume and variation; do not open a record yet.",
      "After explaining the view, search for EIR-2025-0041.",
      "Open Hargrove, Robert - Unreported SSDI Wages Q1-Q2 2025 as the final action in this step.",
    ],
    notes: [
      "Each row is an out-of-box Dynamics Case extended with earnings-integrity fields.",
      "The additional records demonstrate repeatable patterns across unreported earnings, multiple employers, employer mismatch, and late reporting.",
      "The Hargrove wage-match signal indicates $24,800 across two quarters while the beneficiary-reported amount is zero.",
    ],
    callout: "The suspicious wage signal opens structured work. It does not predetermine fraud, eligibility, debt, or disposition.",
    transition: "With the workload context established, I will open Hargrove and continue on the case Summary.",
  },
  {
    id: "case-summary",
    number: "05",
    title: "Hero Case Summary, Navigation, and Guided Process",
    minutes: 5,
    purpose: "Orient the audience to the open hero record, its navigation, and the guided lifecycle.",
    actions: [
      "Begin with the generated Summary at the top; point to its AI-content caution, Copy, Translate, feedback, and refresh controls.",
      "Show that Hargrove is open, then point to the case header: title, case number, current status, High priority, and owner.",
      "Point to the visible active-case commands, including Refresh, Assign or routing actions, Add to Queue, the overflow menu, and Share as available.",
      "Explain that if or when the case is resolved, it becomes read-only; an authorized user can reactivate it if more work is required.",
      "Orient the audience to Intake, Risk & Confidence, Evidence & Workflow, Workbench, AI Insights, Review, Attachments, and Related.",
      "Point to Intake Triage, Case Details, Risk Decision, Analysis, and Case Closure in the Business Process Flow.",
      "On Intake, show Intake Classification and use the Timeline to establish the operational record beneath the summary.",
    ],
    notes: [
      "The generated Summary gives a quick orientation to the prepared case, but the caution label matters: staff verify generated content against the underlying record.",
      "Hargrove remains open for active review. Commands vary by status, role, and configuration.",
      "Resolution protects the completed state by making the record read-only. Reactivation is an authorized path for additional work; it is not the current state of this hero case.",
      "The form tabs organize the review while keeping case, evidence, findings, activities, and decisions connected in Dataverse.",
      "The visible five-stage Business Process Flow is a configured demonstration baseline. Its labels and behavior do not claim a finalized SSA workflow.",
      "The generated Summary supports orientation; the dedicated AI Insights tab later shows the scenario's more structured assistive-analysis pattern.",
    ],
    callout: "The summary accelerates orientation, the record preserves the facts, and the process guide makes the work repeatable.",
  },
  {
    id: "risk-confidence",
    number: "06",
    title: "Risk and Confidence",
    minutes: 3,
    purpose: "Show explainable prioritization while separating risk signals from decision authority.",
    actions: [
      "Open Risk & Confidence.",
      "Point to Risk Level, Fraud Risk Score, Fraud Likelihood, and Risk Explanation.",
      "Point to Confidence Level and Confidence Score.",
      "Show Potential Overpayment Estimate, Largest Monthly Variance, and Impacted Months.",
    ],
    notes: [
      "Risk describes why a case may deserve attention. Confidence describes how strongly the available data supports the current assessment.",
      "The Hargrove explanation references two quarters of zero reported earnings, verified wage data, employer confirmation, and a sustained pattern.",
      "The scores and thresholds are demonstration choices. SSA could change the factors, require different review, or remove a score.",
    ],
    callout: "The score helps a person decide what to review first; it does not decide the case.",
    status: "Demonstrated: structured risk/confidence display. Production scoring requires approved logic, data validation, monitoring, explainability, and governance.",
  },
  {
    id: "evidence-workflow",
    number: "07",
    title: "Evidence and Workflow",
    minutes: 4,
    purpose: "Show how conflicting information is organized and how human oversight remains visible.",
    actions: [
      "Open Evidence & Workflow.",
      "Show evidence, identity validation, and beneficiary response status.",
      "Show queue, human review, supervisor review, approval, recommended outcome, and final determination.",
      "Show both Hargrove discrepancy records: $12,400 each.",
      "Show W-2/tax record, beneficiary statement, and employer confirmation evidence.",
      "Show the Investigation Finding pending supervisor action.",
    ],
    notes: [
      "The top fields summarize what is complete and unresolved; related records preserve supporting detail.",
      "One discrepancy record per period and employer makes the $24,800 total explainable and reportable.",
      "The wage record and employer confirmation support the discrepancy. The beneficiary statement remains contradictory and under review.",
      "Supervisor and human-review flags reflect this open demo workflow; SSA could define different approval paths.",
    ],
    callout: "The decision is explainable because discrepancy, evidence, finding, and human checkpoints remain connected to one case.",
  },
  {
    id: "workbench",
    number: "08",
    title: "Analyst Case Workbench",
    minutes: 3,
    purpose: "Show a purpose-built view that assembles the case without replacing source records.",
    actions: [
      "Open Workbench.",
      "Point to case header, status, type, days open, and total exposure.",
      "Show Earnings Discrepancy Comparison.",
      "Show Evidence Collection and verification details.",
      "Walk the Case Progress Checklist through supervisor approval.",
    ],
    notes: [
      "The embedded workbench reads related Dataverse records and presents the analyst's most important information in one compact view.",
      "The underlying case, discrepancy, evidence, and finding records remain the system of record.",
      "SSA could change the checklist, wording, order, level of detail, or provide a different view by role.",
    ],
    callout: "The workbench reduces navigation while preserving structured, auditable records underneath.",
  },
  {
    id: "ai-insights",
    number: "09",
    title: "AI Insights with Human Guardrails",
    minutes: 3,
    purpose: "Demonstrate assistive summarization and triage patterns with transparent limits.",
    actions: [
      "Open AI Insights.",
      "Show Case Summary, Supporting Evidence, Next Best Action, Risk Signals, Evidence Gaps, Confidence Rationale, Human Review Note, and Raw JSON.",
      "Show the embedded Fraud AI Insights display and status label.",
      "Point to Refresh Display.",
      "Do not select Run AI Analysis unless the trigger was prevalidated.",
    ],
    notes: [
      "The output is separated into inspectable sections instead of one unqualified paragraph.",
      "Bulk-case content is explicitly seeded demonstration analysis. The build records ai_model_called = false for those values.",
      "AI output does not determine fraud, eligibility, overpayment, escalation, or final disposition.",
      "Production use requires approved models and prompts, security/privacy review, grounding, evaluation, monitoring, audit, and exception handling.",
    ],
    callout: "AI can organize the evidence and suggest the next question; accountable staff make the decision.",
    status: "Demonstrated: assistive display pattern. Seeded bulk values are not live model results, and production AI is not claimed.",
  },
  {
    id: "agent-support",
    number: "10",
    title: "Specialized Agent and Frontline Support",
    minutes: 3,
    purpose: "Show role-specific guidance and authoritative routing at the point of work without replacing policy or human judgment.",
    actions: [
      "Open SSA Agent Support and show Linked Agents (3).",
      "Explain that the agents can use approved website content to ground employee support.",
      "Identify Earnings Fraud Navigator as subject-specific, NORA as broad organizational support, and General IT as technical support.",
      "Select Federal Earnings Fraud Navigator and show the bounded response to the $24,000 question.",
      "Point to relevant regulations/current guidance and the OIG or criminal-matter escalation distinction.",
      "Switch to the purpose-built SSA Agent Fraud Support tab and show fraud guidance, OIG reporting, office lookup, official source, and call triage.",
    ],
    notes: [
      "The agents can use approved website content to ground assistance and help employees find relevant information without searching disconnected pages.",
      "The Earnings Fraud Navigator supports this subject specifically; NORA provides broad organizational guidance and general understanding; General IT handles technical support.",
      "The navigator does not invent a special $24,000 threshold. It directs the employee to governing regulations, current SSA guidance, and appropriate escalation.",
      "The response is not policy or legal authority. Staff rely on current approved sources and authorized decision makers.",
      "The second tab is a purpose-built navigation page for frontline agents, with direct paths to fraud guidance, OIG reporting, office lookup, official sources, and call triage.",
      "Conversational agents answer and route questions; the support page gives the employee a consistent path through the task.",
    ],
    callout: "Grounded agents help employees understand and find information; the support page helps them navigate the task. Neither creates policy nor decides the case.",
    status: "Demonstrated: website-grounded guidance, routing, and frontline navigation. Production requires approved sources, content ownership, freshness controls, access rules, evaluation, audit, and escalation boundaries.",
    transition: "With the evidence organized and the employee connected to the appropriate guidance, I will return to the structured finding and supervisor decision surface.",
  },
  {
    id: "supervisor-review",
    number: "11",
    title: "Investigation Finding and Supervisor Review",
    minutes: 4,
    purpose: "Complete the human decision path and show the supervisor's concise decision surface.",
    actions: [
      "Close Agent Support, return to Hargrove, open Evidence & Workflow, and select the Investigation Finding.",
      "Show Finding Type, Severity, Recommended Disposition, Approval Status, Analyst, and supporting detail.",
      "Return to the case and open Review.",
      "Show discrepancy records, evidence package, analyst recommendation, and pending approval.",
      "Point to the supervisor decision options without selecting one.",
    ],
    notes: [
      "The finding records what the analyst concluded, severity, recommended disposition, author, and supervisor status.",
      "The Review tab assembles exposure, discrepancy records, evidence verification, and analyst recommendation.",
      "The displayed supervisor options are demonstration choices, not a statement of SSA's required outcome taxonomy.",
      "Hargrove remains open and pending so the demo stops immediately before the accountable human decision.",
    ],
    callout: "The system prepares the decision package; the supervisor owns the decision.",
  },
  {
    id: "tasks-process",
    number: "12",
    title: "Tasks, Scale, and Process Improvement",
    minutes: 3,
    purpose: "Show day-to-day follow-up work and the foundation for process-level improvement.",
    actions: [
      "Return briefly to Earnings Integrity - Analyst Dashboard and point to Open Tasks.",
      "Explain the 60 open tasks across 20 recent cases.",
      "Name the three task types: Intake and Risk, Evidence Review, Follow-Up and Disposition.",
      "Optionally open Process Events and show activity, timestamps, resource, queue/team, risk, evidence, outcome, and synthetic indicator.",
    ],
    notes: [
      "A case review includes follow-up work, not only a form. Task categories and due-date logic are configurable.",
      "The 12-case Process Mining cohort includes straight-through, evidence-loop, supervisor-return, reassignment, and escalation variants.",
      "Those event rows are explicitly synthetic demonstration instrumentation, not reconstructed SSA history or production audit data.",
    ],
    callout: "The platform can manage today's work and provide evidence for improving tomorrow's process when event lineage is trustworthy.",
  },
  {
    id: "configuration",
    number: "13",
    title: "Configuration and Production Path",
    minutes: 2,
    purpose: "Prevent the demonstration from being mistaken for a final solution blueprint.",
    actions: [
      "Restate that stages, labels, evidence categories, supervisor options, workbench layouts, and dashboards are examples.",
      "Separate reusable platform capabilities from SSA-specific policy and operating-model design.",
      "Name the production work: requirements, integrations, security/privacy, records, accessibility, performance, operations, governance, migration, and acceptance.",
    ],
    notes: [
      "Dynamics and Dataverse provide cases, contacts, activities, ownership, teams, queues, forms, views, process guidance, relational data, security, auditing, packaging, and endpoints.",
      "SSA discovery would define the domain configuration layered on top.",
      "Production readiness requires requirement-by-requirement validation and governed engineering, not simply promoting the demo environment.",
    ],
    callout: "What is reusable is the platform pattern. What must be designed with SSA is the policy and operating model.",
  },
  {
    id: "closing",
    number: "14",
    title: "Closing",
    minutes: 2,
    purpose: "Summarize the connected pattern and end with a discovery question.",
    actions: [
      "Recap workload, dashboard, Hargrove signal, guided review, risk, evidence, workbench, AI, Agent Support, finding, and supervisor package.",
      "Restate structured records, visible human checkpoints, and measures that trace to operational work.",
      "Repeat that this is one configuration built to make the conversation concrete.",
      "Ask which process area SSA would most value mapping next.",
    ],
    notes: [
      "We followed a $24,800 discrepancy from workload visibility through AI and point-of-work agent support to the complete supervisor decision package.",
      "The demonstration shows connected records instead of disconnected notes and visible human checkpoints instead of autonomous decisions.",
      "The next step is to use these screens to ask better questions about real intake paths, evidence authority, stages, decision rights, waiting, returns, and measures.",
    ],
    callout: "Which part of the current earnings integrity process would be most valuable to map next: intake and routing, evidence collection, supervisor review, or program visibility?",
  },
];

const guardrails = [
  "Fictional demonstration data only.",
  "A wage signal is not a fraud determination.",
  "AI assists; analysts and supervisors decide.",
  "Agent guidance is not policy authority or adjudication.",
  "Bulk AI values are seeded, not live model output.",
  "Process Mining events are synthetic demo instrumentation.",
  "The visible BPF is a multi-stage demonstration baseline.",
];

const questions = [
  ["Is this the process SSA should adopt?", "No. It is one working configuration used to demonstrate capabilities and drive discovery."],
  ["Is this production-ready?", "No. Production requires validated requirements, integrations, security/privacy, records, accessibility, performance, operations, governance, migration, and acceptance testing."],
  ["Is AI making the decision?", "No. AI is positioned as assistive summarization and triage. Staff retain final authority."],
  ["Are the dashboard numbers SSA metrics?", "No. They are calculations over fictional demonstration data. SSA would define approved measures."],
  ["Is Process Mining based on production history?", "No. The enriched cohort is explicitly synthetic demonstration instrumentation."],
  ["Can the screens and terminology change?", "Yes. Forms, views, dashboards, labels, stages, queues, security, rules, and embedded experiences are configurable and solution-managed."],
];

const recoveryNotes = [
  "Dashboard slow: use the Cases view and narrate the same workload dimensions.",
  "Web resource blank: return to the related-record grids; records are evidence, the web resource is presentation.",
  "BPF will not advance: do not edit the hero case live; explain the visible pattern and continue through tabs.",
  "AI refresh fails: state that the live trigger is not configured for this browser session; do not imply completion.",
  "Time short: skip Process Events, but preserve supervisor review and configuration sections.",
];

function getInitialState() {
  const fallback = { completed: {}, actions: {}, expanded: {}, elapsed: 0, running: false, startedAt: null, fontScale: 1 };
  try {
    return { ...fallback, ...JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}") };
  } catch {
    return fallback;
  }
}

function formatTime(seconds) {
  const safe = Math.max(0, Math.floor(seconds));
  const minutes = Math.floor(safe / 60);
  const remaining = safe % 60;
  return `${minutes}:${String(remaining).padStart(2, "0")}`;
}

function App() {
  const [state, setState] = useState(getInitialState);
  const [now, setNow] = useState(Date.now());
  const [activeId, setActiveId] = useState("opening");
  const [navOpen, setNavOpen] = useState(false);
  const [resetOpen, setResetOpen] = useState(false);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    document.documentElement.style.setProperty("--presenter-scale", state.fontScale);
  }, [state]);

  useEffect(() => {
    if (!state.running) return undefined;
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [state.running]);

  const elapsed = state.elapsed + (state.running && state.startedAt ? (now - state.startedAt) / 1000 : 0);
  const remaining = TARGET_SECONDS - elapsed;
  const timedProgress = Math.min(100, (elapsed / TARGET_SECONDS) * 100);
  const timedSections = sections.filter((section) => section.minutes > 0);
  const completedCount = timedSections.filter((section) => state.completed[section.id]).length;
  const sectionProgress = (completedCount / timedSections.length) * 100;
  const actionTotal = sections.reduce((sum, section) => sum + section.actions.length, 0);
  const actionDone = Object.values(state.actions).filter(Boolean).length;
  const activeSection = sections.find((section) => section.id === activeId) || sections[1];

  const cumulative = useMemo(() => {
    let total = 0;
    return Object.fromEntries(
      sections.map((section) => {
        total += section.minutes;
        return [section.id, total];
      }),
    );
  }, []);

  const patchState = (patch) => setState((current) => ({ ...current, ...patch }));

  const toggleTimer = () => {
    if (state.running) {
      patchState({ elapsed, running: false, startedAt: null });
    } else {
      patchState({ running: true, startedAt: Date.now() });
      setNow(Date.now());
    }
  };

  const toggleSection = (section) => {
    const nextValue = !state.completed[section.id];
    const actions = { ...state.actions };
    section.actions.forEach((_, index) => {
      actions[`${section.id}:${index}`] = nextValue;
    });
    patchState({ completed: { ...state.completed, [section.id]: nextValue }, actions });
  };

  const toggleAction = (section, index) => {
    const key = `${section.id}:${index}`;
    const actions = { ...state.actions, [key]: !state.actions[key] };
    const allComplete = section.actions.every((_, actionIndex) => Boolean(actions[`${section.id}:${actionIndex}`]));
    patchState({ actions, completed: { ...state.completed, [section.id]: allComplete } });
  };

  const toggleExpanded = (id) => patchState({ expanded: { ...state.expanded, [id]: state.expanded[id] === false } });

  const jumpTo = (id) => {
    setActiveId(id);
    setNavOpen(false);
    window.requestAnimationFrame(() => document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" }));
  };

  const nextIncomplete = () => {
    const next = timedSections.find((section) => !state.completed[section.id]) || timedSections[0];
    jumpTo(next.id);
  };

  const setAllExpanded = (value) => patchState({ expanded: Object.fromEntries(sections.map((section) => [section.id, value])) });

  const toggleTheme = () => {
    const next = document.documentElement.getAttribute("data-theme") === "dark" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", next);
    localStorage.setItem("ssa-presenter-theme", next);
  };

  const reset = () => {
    const clean = { completed: {}, actions: {}, expanded: {}, elapsed: 0, running: false, startedAt: null, fontScale: 1 };
    setState(clean);
    setNow(Date.now());
    setResetOpen(false);
    setActiveId("opening");
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  return (
    <div className="app-shell">
      <header className="topbar">
        <div className="brand-block">
          <button className="icon-button mobile-menu" onClick={() => setNavOpen(true)} title="Open section navigation" aria-label="Open section navigation"><Menu size={20} /></button>
          <div>
            <div className="eyebrow">SSA EARNINGS INTEGRITY</div>
            <h1>40-Minute Demo Companion</h1>
          </div>
        </div>

        <div className="header-metrics">
          <div className="metric compact-metric">
            <span>Sections</span>
            <strong>{completedCount}/{timedSections.length}</strong>
          </div>
          <div className={`timer-readout ${remaining < 0 ? "overtime" : ""}`}>
            <Clock3 size={18} />
            <div><span>{remaining >= 0 ? "Remaining" : "Overtime"}</span><strong>{remaining >= 0 ? formatTime(remaining) : `+${formatTime(-remaining)}`}</strong></div>
          </div>
          <button className="primary-button" onClick={toggleTimer}>{state.running ? <Pause size={17} /> : <Play size={17} />}{state.running ? "Pause" : elapsed > 0 ? "Resume" : "Start"}</button>
        </div>

        <div className="header-tools">
          <button className="icon-button" onClick={nextIncomplete} title="Jump to next incomplete section" aria-label="Jump to next incomplete section"><SkipForward size={19} /></button>
          <button className="icon-button" onClick={() => patchState({ fontScale: Math.max(0.9, state.fontScale - 0.1) })} title="Decrease text size" aria-label="Decrease text size"><Minus size={18} /></button>
          <button className="icon-button" onClick={() => patchState({ fontScale: Math.min(1.3, state.fontScale + 0.1) })} title="Increase text size" aria-label="Increase text size"><Plus size={18} /></button>
          <button className="icon-button" onClick={toggleTheme} title="Toggle light or dark theme" aria-label="Toggle light or dark theme"><Contrast size={18} /></button>
          <button className="icon-button danger-button" onClick={() => setResetOpen(true)} title="Reset demo progress" aria-label="Reset demo progress"><RotateCcw size={18} /></button>
        </div>
        <div className="time-progress"><span style={{ width: `${timedProgress}%` }} /></div>
      </header>

      <aside className={`section-nav ${navOpen ? "nav-open" : ""}`}>
        <div className="nav-heading">
          <div><span>RUN OF SHOW</span><strong>40 minutes</strong></div>
          <button className="icon-button nav-close" onClick={() => setNavOpen(false)} title="Close navigation" aria-label="Close navigation"><X size={19} /></button>
        </div>
        <div className="overall-progress" aria-label={`${Math.round(sectionProgress)} percent of timed sections complete`}>
          <span style={{ width: `${sectionProgress}%` }} />
        </div>
        <nav>
          {sections.map((section) => {
            const done = Boolean(state.completed[section.id]);
            const current = activeId === section.id;
            return (
              <button key={section.id} className={`nav-item ${current ? "current" : ""} ${done ? "done" : ""}`} onClick={() => jumpTo(section.id)}>
                <span className="nav-number">{done ? <Check size={14} /> : section.number}</span>
                <span className="nav-copy"><strong>{section.title}</strong><small>{section.minutes ? `${section.minutes} min · ${cumulative[section.id]} min mark` : "Before audience joins"}</small></span>
              </button>
            );
          })}
        </nav>
        <div className="nav-footer">
          <span>{actionDone}/{actionTotal} actions checked</span>
          <div><button onClick={() => setAllExpanded(true)}>Expand</button><button onClick={() => setAllExpanded(false)}>Collapse</button></div>
        </div>
      </aside>

      {navOpen && <button className="nav-scrim" onClick={() => setNavOpen(false)} aria-label="Close section navigation" />}

      <main className="presenter-main">
        <section className="orientation-band">
          <div className="orientation-copy">
            <span className="status-dot" />
            <div><strong>One configurable demonstration</strong><p>Fictional data · Assistive AI · Human decisions · Synthetic process events clearly labeled</p></div>
          </div>
          <div className="active-marker"><span>Now showing</span><strong>{activeSection.number} · {activeSection.title}</strong></div>
        </section>

        <section className="guardrail-strip" aria-label="Demonstration guardrails">
          <ShieldCheck size={20} />
          <div>{guardrails.map((guardrail) => <span key={guardrail}>{guardrail}</span>)}</div>
        </section>

        {sections.map((section) => {
          const expanded = state.expanded[section.id] !== false;
          const done = Boolean(state.completed[section.id]);
          const checkedActions = section.actions.filter((_, index) => state.actions[`${section.id}:${index}`]).length;
          return (
            <article id={section.id} key={section.id} className={`demo-section ${done ? "section-complete" : ""}`} onMouseEnter={() => setActiveId(section.id)}>
              <header className="section-header">
                <label className="section-check" title={done ? "Mark section incomplete" : "Mark section and all actions complete"}>
                  <input type="checkbox" checked={done} onChange={() => toggleSection(section)} />
                  <span>{done ? <Check size={20} /> : section.number}</span>
                </label>
                <button className="section-title-button" onClick={() => toggleExpanded(section.id)} aria-expanded={expanded}>
                  <span className="section-kicker">{section.minutes ? `TIMED SECTION · ${section.minutes} MINUTES` : "READINESS CHECK"}</span>
                  <h2>{section.title}</h2>
                  <p>{section.purpose}</p>
                </button>
                <div className="section-header-meta">
                  <span>{checkedActions}/{section.actions.length}</span>
                  <button className="icon-button" onClick={() => toggleExpanded(section.id)} title={expanded ? "Collapse section" : "Expand section"} aria-label={expanded ? "Collapse section" : "Expand section"}>{expanded ? <ChevronDown size={20} /> : <ChevronRight size={20} />}</button>
                </div>
              </header>

              {expanded && (
                <div className="section-content">
                  <section className="speaker-column">
                    <h3>What to Say</h3>
                    <div className="speaker-notes">
                      {section.notes.map((note) => <blockquote key={note}>{note}</blockquote>)}
                    </div>
                    {section.callout && <div className="callout"><span>KEY LINE</span><strong>{section.callout}</strong></div>}
                    {section.status && <div className="status-language"><span>POSITIONING</span><p>{section.status}</p></div>}
                    {section.transition && <div className="transition"><span>TRANSITION</span><p>{section.transition}</p></div>}
                  </section>

                  <section className="action-column">
                    <h3><ListChecks size={18} /> On Screen</h3>
                    <div className="action-list">
                      {section.actions.map((action, index) => {
                        const key = `${section.id}:${index}`;
                        return (
                          <label key={key} className={`action-item ${state.actions[key] ? "action-done" : ""}`}>
                            <input type="checkbox" checked={Boolean(state.actions[key])} onChange={() => toggleAction(section, index)} />
                            <span className="custom-check">{state.actions[key] && <Check size={15} />}</span>
                            <span>{action}</span>
                          </label>
                        );
                      })}
                    </div>
                  </section>
                </div>
              )}
            </article>
          );
        })}

        <section className="reference-section">
          <header><span>LIVE SUPPORT</span><h2>Questions and Recovery</h2><p>Keep these concise answers and fallback routes available without leaving the page.</p></header>
          <div className="reference-grid">
            <div className="reference-panel">
              <h3>Likely Questions</h3>
              {questions.map(([question, answer]) => <details key={question}><summary>{question}</summary><p>{answer}</p></details>)}
            </div>
            <div className="reference-panel">
              <h3>Recovery Notes</h3>
              <ul>{recoveryNotes.map((note) => <li key={note}>{note}</li>)}</ul>
            </div>
          </div>
        </section>
      </main>

      {resetOpen && (
        <div className="modal-backdrop" role="presentation">
          <div className="reset-dialog" role="dialog" aria-modal="true" aria-labelledby="reset-title">
            <RotateCcw size={24} />
            <h2 id="reset-title">Reset demo progress?</h2>
            <p>This clears every checkbox and returns the timer to 40:00. It cannot be undone.</p>
            <div><button className="secondary-button" onClick={() => setResetOpen(false)}>Cancel</button><button className="primary-button" onClick={reset}>Reset</button></div>
          </div>
        </div>
      )}
    </div>
  );
}

const storedTheme = localStorage.getItem("ssa-presenter-theme");
if (storedTheme) document.documentElement.setAttribute("data-theme", storedTheme);
createRoot(document.getElementById("root")).render(<App />);