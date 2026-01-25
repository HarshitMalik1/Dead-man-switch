## 2026-01-25 - [Unauthorized Trigger Access]
**Vulnerability:** `triggerSwitch` lacked `onlyAuthorized` modifier, allowing public access contrary to documentation.
**Learning:** Always verify access control modifiers are applied to sensitive functions, even if they exist in the codebase.
**Prevention:** Audit all external/public functions against intended access control policies.
