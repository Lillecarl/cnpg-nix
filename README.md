# cnpg-nix
Builds an OCI image that's compatible with [CloudNativePG](https://cloudnative-pg.io/) using Nix.

## Why?
Databases are kinda important, being able to 100% reproduce your database might be useful at some point. And Nix makes it very easy to pin versions of everything. You can also go absolutely bonkers with plugins without worry, and you don't have to write a Dockerfile/Containerfile/whatever.
