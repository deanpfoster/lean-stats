#!/usr/bin/env Rscript
# Conformance/R/vif_regression.R
# Run this to generate the golden fixture for VIF-Regression.
# Output: the selected variable indices on a known dataset.
#
# Usage: Rscript Conformance/R/vif_regression.R
#
# Requires: install.packages("VIF")

library(VIF)

# Test 1: Simple signal + noise
# y = 2*x0 + small noise, x1 is random, x2 is constant
set.seed(42)
y <- c(2.1, 4.0, 5.9, 8.1, 10.0)
x <- matrix(c(
  1, 2, 3, 4, 5,    # x0: signal
  5, 3, 1, 4, 2,    # x1: noise
  2, 2, 2, 2, 2     # x2: constant
), ncol=3)

result <- vif(y, x, w0=0.5, dw=0.1, subsize=5, trace=FALSE)
cat("Test 1 - simple signal+noise:\n")
cat("  selected indices (1-based):", result$select, "\n")
cat("  expected: 1 (only x0)\n\n")

# Test 2: Boston housing with interactions (from the package example)
data(housingexp)
result2 <- vif(housingexp$y, housingexp$x, w0=0.0005, dw=0.005, subsize=300, trace=FALSE)
cat("Test 2 - Boston housing with interactions:\n")
cat("  n selected:", length(result2$select), "\n")
cat("  selected indices:", head(result2$select, 20), "\n")
cat("  total candidates:", ncol(housingexp$x), "\n\n")

# Test 3: Synthetic data (from the package)
data(syn)
result3 <- vif(syn$y, syn$x, trace=FALSE)
cat("Test 3 - Synthetic data:\n")
cat("  selected:", result3$select, "\n")
cat("  true signal:", syn$true, "\n")
cat("  match:", all(sort(result3$select) == sort(syn$true)), "\n")
