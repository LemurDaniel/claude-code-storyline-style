# YAML pipeline examples
| File | Content |
| --- | --- |
| `deploy.infra.dev.yaml` | Thin entry point per environment, calls the template. |
| `tmpl.terraform.infra.deploy.yaml` | Reusable workflow: config, plan, approve, apply. |
