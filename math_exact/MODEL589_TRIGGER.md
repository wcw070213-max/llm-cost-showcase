# Model 589 exact SCIP/VIPR trigger

All eight frozen model-589 transport chunks are present. This commit triggers the dedicated workflow: cold-replay model 352 original-problem certificate as a hard gate, then run model 589 with exact SCIP 10.0.3, presolving and separation disabled, and accept UNSAT only after a non-tautological VIPR certificate is independently checked.
