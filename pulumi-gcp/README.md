# pulumi-gcp

An opinionated [Pulumi](https://www.pulumi.com/) workflow with a **Google Cloud Storage** (or local) state backend. Uses Pulumi **stacks** and per-stack YAML config.

**Full documentation:** <https://serpro69.github.io/devex-makefile/iac/pulumi-gcp/>

## Quick start

```bash
# from your project root
git submodule add https://github.com/serpro69/devex-makefile.git
ln -s devex-makefile/pulumi-gcp/Makefile Makefile

# configure GCP + backend + stack, then preview/up
GCP_PROJECT=my-project STACK=demo make init
make preview
make up

# discover everything the makefile can do
make help
```

> [!NOTE]
> The state project and bucket are currently hardcoded to the author's environment — edit them in the `Makefile` before use. See the [documentation](https://serpro69.github.io/devex-makefile/iac/pulumi-gcp/#input-variables) for details.
