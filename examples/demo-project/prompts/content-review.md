---
schema: document/v1
id: prompt:demo-content-review
kind: prompt
title: Content review prompt
summary: Review a draft for clarity, grounding, and actionable revisions.
created_at: '2026-08-22T00:00:00Z'
updated_at: '2026-08-22T00:00:00Z'
status: active
tags: [review, example]
inputs:
  - name: draft
    type: string
    required: true
    secret: false
outputs:
  - name: review
    type: string
    required: true
    secret: false
provenance:
  source_type: authored
---

You are a precise content reviewer. Review the supplied draft for clarity, grounding, and actionable revisions. Return strengths, issues, and prioritized actions.
