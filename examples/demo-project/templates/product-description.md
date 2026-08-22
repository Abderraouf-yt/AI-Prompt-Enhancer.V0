---
schema: document/v1
id: template:demo-product-description
kind: template
title: Product description template
summary: Write a product description for a defined audience and language.
created_at: '2026-08-22T00:00:00Z'
updated_at: '2026-08-22T00:00:00Z'
status: active
tags: [template, example]
inputs:
  - name: product
    type: string
    required: true
    secret: false
  - name: audience
    type: string
    required: true
    secret: false
  - name: language
    type: string
    required: false
    secret: false
    default: English
provenance:
  source_type: imported
  source_label: Example external prompt
  adaptation:
    mode: template
    project_id: project:demo-content-workspace
    changed_sections: [variables]
---

Write a product description for {{product}} targeting {{audience}} in {{language}}. Keep the language clear, specific, and honest. End with three concise benefits.
