import DeanLean.Basic
import LeanStats.Manifest
import LeanStats.Anova
import LeanStats.Proportion
import LeanTab.Manifest
import LeanTab.CatalogJson
import LeanTab.TwoEyed
import LeanTab.Clean
import LeanTab.Join
import LeanTab.Sample
import LeanTab.JoinDiscovery
import LeanTab.SchemaValidation
import LeanStats.AlphaInvesting
import LeanStats.Eval
import LeanStats.Plot.Describe
import LeanStats.Plot.Terminal
import LeanStats.Plot.Protocol
import LeanStats.Report.Provenance
import LeanStats.Report.Literate

/-! # Purity audit — verify no IO leaks into the library

This file defines a root constant that transitively reaches all
public API functions. The `PureExcept` macro verifies that no
IO-bearing constants are reachable from this root.

If this file compiles without error, the library is pure.
-/
-- Purity audit. Referenced by: LeanStats/Manifest.lean

set_option autoImplicit false

namespace LeanStats.Audit

/-- Root constant that touches all major public API functions.
    PureExcept walks the transitive closure from here. -/
noncomputable def auditEntryPoint :=
  -- Descriptive
  (LeanStats.mean, LeanStats.variance, LeanStats.stdDev, LeanStats.median,
   LeanStats.quantile, LeanStats.summary, LeanStats.iqr,
  -- Regression
   LeanStats.correlation, LeanStats.linearRegression, LeanStats.regressionDiag,
   LeanStats.correlationTest, LeanStats.regressionConfInt,
   LeanStats.predictCI, LeanStats.predictPI,
  -- Tests
   LeanStats.tTestOneSample, LeanStats.tTestTwoSample, LeanStats.tTestPaired,
  -- Anova
   LeanStats.oneWayAnova, LeanStats.tukeyHSD,
  -- Proportion
   LeanStats.chiSquaredTest, LeanStats.propTestOne, LeanStats.propTestTwo,
  -- Transform
   LeanStats.logTransform, LeanStats.sqrtTransform, LeanStats.bestResponseTransform,
  -- Diagnostics
   LeanStats.regressionSummary, LeanStats.outliersByStdResid,
   LeanStats.influentialByCooksD, LeanStats.residQQ,
  -- AlphaInvesting
   LeanStats.alphaInvesting, LeanStats.computeSE,
  -- Eval
   LeanStats.Eval.evalString,
  -- Plot descriptions
   LeanStats.Plot.describeScatter, LeanStats.Plot.describeHistogram,
   LeanStats.Plot.describeDiag,
  -- Terminal plots
   LeanStats.Plot.Terminal.terminalScatter, LeanStats.Plot.Terminal.terminalHistogram,
   LeanStats.Plot.Terminal.sparkline, LeanStats.Plot.Terminal.terminalDotplot,
   LeanStats.Plot.Terminal.terminalBoxplot,
  -- Protocol
   LeanStats.Plot.Protocol.encodeCommand, LeanStats.Plot.Protocol.parseEvent,
  -- Report
   LeanStats.Report.renderDocument, LeanStats.Report.extractScript,
   LeanStats.Report.parseLiterate,
  -- Table
   LeanTab.parseCsv, LeanTab.renderCsv, LeanTab.prettyPrint,
   LeanTab.filter, LeanTab.select, LeanTab.mutate, LeanTab.arrange,
   LeanTab.groupBy, LeanTab.count, LeanTab.innerJoin, LeanTab.leftJoin,
   LeanTab.pivotLonger, LeanTab.pivotWider,
   LeanTab.dropNa, LeanTab.fillForward, LeanTab.replaceNa,
   LeanTab.slice, LeanTab.sampleN,
   LeanTab.Sql.parseExpr, LeanTab.Sql.filterByExpr, LeanTab.Sql.eval,
   LeanTab.runQuery, LeanTab.tableSummary,
  -- Catalog
   LeanTab.catalogFromTable, LeanTab.assessQuality,
   LeanTab.DataCatalog.search, LeanTab.DataCatalog.toJsonString,
   LeanTab.DataCatalog.upsert, LeanTab.DataSource.refreshFrom,
  -- Crypto
   LeanTab.Crypto.encrypt, LeanTab.Crypto.decrypt,
  -- Clean
   LeanTab.autoClean,
  -- JoinDiscovery
   LeanTab.discoverJoinKeys,
  -- SchemaValidation
   LeanTab.validateAgainstCatalog)

-- The purity check: no IO reachable from auditEntryPoint
PureExcept LeanStats.Audit.auditEntryPoint allows

end LeanStats.Audit
