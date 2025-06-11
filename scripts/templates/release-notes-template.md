# {{TITLE}}

{{#if SUMMARY_ENABLED}}
## Summary

**{{TOTAL_COMMITS}} commits** across {{CATEGORY_COUNT}} categories:

{{#each CATEGORY_SUMMARY}}
- {{EMOJI}} {{NAME}}: {{COUNT}} commits
{{/each}}

{{/if}}

{{#if BREAKING_CHANGES}}
## ⚠️ BREAKING CHANGES

{{#each BREAKING_CHANGES}}
- {{.}}
{{/each}}

{{/if}}

## Changes

{{#each CATEGORIES}}
### {{EMOJI}} {{NAME}}

{{#each COMMITS}}
- {{.}}
{{/each}}

{{/each}}

{{#if FOOTER_ENABLED}}
---

_Generated on {{GENERATED_DATE}} from commits {{FROM_TAG}}..{{TO_TAG}}_
{{#if VERSION}}_Version: {{VERSION}}_{{/if}}
{{/if}}