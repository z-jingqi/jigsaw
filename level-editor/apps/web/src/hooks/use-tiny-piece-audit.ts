import * as React from "react";
import { auditTinyPieces } from "../api";
import type { LevelCatalog, SelectedLevel, TinyPieceAuditResponse, TinyPieceAuditResult } from "../types";

export function tinyPieceAuditKey(target: SelectedLevel) {
  return `${target.topicId}/${target.groupId}/${target.levelId}`;
}

function catalogTargets(catalog: LevelCatalog): SelectedLevel[] {
  const targets: SelectedLevel[] = [];
  for (const topic of catalog.topics) {
    for (const group of topic.groups) {
      for (const level of group.levels) {
        targets.push({ topicId: topic.id, groupId: group.id, levelId: level.id });
      }
    }
  }
  return targets;
}

export function useTinyPieceAudit(catalog: LevelCatalog) {
  const targets = React.useMemo(() => catalogTargets(catalog), [catalog]);
  const signature = React.useMemo(() => targets.map(tinyPieceAuditKey).join("|"), [targets]);
  const previousKeys = React.useRef<Set<string>>(new Set());
  const requestVersion = React.useRef(0);
  const [selectedKeys, setSelectedKeys] = React.useState<Set<string>>(new Set());
  const [findings, setFindings] = React.useState<Map<string, TinyPieceAuditResult>>(new Map());
  const [summary, setSummary] = React.useState<TinyPieceAuditResponse | null>(null);
  const [running, setRunning] = React.useState(false);

  React.useEffect(() => {
    const available = new Set(targets.map(tinyPieceAuditKey));
    setSelectedKeys((current) => {
      const next = new Set([...current].filter((key) => available.has(key)));
      for (const key of available) {
        if (!previousKeys.current.has(key)) next.add(key);
      }
      return next;
    });
    previousKeys.current = available;
    requestVersion.current += 1;
    setFindings(new Map());
    setSummary(null);
    setRunning(false);
  }, [signature]);

  function isSelected(target: SelectedLevel) {
    return selectedKeys.has(tinyPieceAuditKey(target));
  }

  function setSelected(target: SelectedLevel, selected: boolean) {
    const key = tinyPieceAuditKey(target);
    setSelectedKeys((current) => {
      const next = new Set(current);
      if (selected) next.add(key);
      else next.delete(key);
      return next;
    });
  }

  function selectAll() {
    setSelectedKeys(new Set(targets.map(tinyPieceAuditKey)));
  }

  function invertSelection() {
    setSelectedKeys((current) => new Set(targets.map(tinyPieceAuditKey).filter((key) => !current.has(key))));
  }

  function selectLastAbnormal() {
    setSelectedKeys(new Set(findings.keys()));
  }

  async function run() {
    const selectedTargets = targets.filter((target) => selectedKeys.has(tinyPieceAuditKey(target)));
    const version = ++requestVersion.current;
    setRunning(true);
    setFindings(new Map());
    setSummary(null);
    try {
      const response = await auditTinyPieces(selectedTargets);
      if (version !== requestVersion.current) return response;
      setFindings(new Map(response.results.filter((result) => result.tinyPieces.length > 0).map((result) => [tinyPieceAuditKey(result), result])));
      setSummary(response);
      return response;
    } finally {
      if (version === requestVersion.current) setRunning(false);
    }
  }

  function findingFor(target: SelectedLevel) {
    return findings.get(tinyPieceAuditKey(target));
  }

  return {
    totalCount: targets.length,
    selectedCount: selectedKeys.size,
    running,
    summary,
    isSelected,
    setSelected,
    selectAll,
    invertSelection,
    selectLastAbnormal,
    run,
    findingFor,
  };
}
