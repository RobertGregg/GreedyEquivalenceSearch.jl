# GreedyEquivalenceSearch

[![Build Status](https://github.com/RobertGregg/GreedyEquivalenceSearch.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/RobertGregg/GreedyEquivalenceSearch.jl/actions/workflows/CI.yml?query=branch%3Amaster)


# Implementation Notes

- cholesky is *slightly* faster and uses half the allocations
- Checking for semi-directed paths is the bottleneck