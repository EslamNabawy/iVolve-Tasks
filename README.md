# iVolve Tasks — DevOps Training

Hands-on labs from the iVolve DevOps training track. Each lab folder contains the artifacts I authored plus a write-up of the steps, output and reasoning.

**Start here:** [GUIDE.md](GUIDE.md) — environment setup (WSL2 / Ubuntu 24.04), Git & GitHub configuration, lab workflow and core concepts.

**Every command explained:** [RUNBOOK.md](RUNBOOK.md) — setup, the git/GitHub workflow, all three labs command by command, and CI/CD pipelines for GitHub Actions and Jenkins.

**Full technical guide:** [LABS-COMPLETE-GUIDE.md](LABS-COMPLETE-GUIDE.md) — every lab explained step by step, every tool and flag, with comparison tables, troubleshooting and a glossary..

## Progress

| # | Track | Lab | Status |
|---|-------|-----|--------|
| 1 | Build Tools | [Building and Packaging a Java App with Maven](Build%20Tools/Lab1/README.md) | ⬜ Not started |
| 2 | Build Tools | [Building and Packaging a Java App with Gradle](Build%20Tools/Lab2/README.md) | ⬜ Not started |
| 3 | Docker | [Creating a Docker Image for a Java Application](Docker/Lab3/README.md) | ⬜ Not started |

Mark a lab ✅ Done when its README is complete and committed.

## Structure

```
iVolve-Tasks
├── Build Tools/   Lab1, Lab2
├── Docker/        Lab3
├── Kubernetes/    (upcoming)
├── Jenkins/       (upcoming)
├── ArgoCD/        (upcoming)
├── Ansible/       (upcoming)
├── GUIDE.md
└── README.md
```

## Application under test

Labs 1–3 all build the same program:

- [CalculatorMavenApp](https://github.com/Ibrahim-Adel15/CalculatorMavenApp)
- [CalculatorGradleApp](https://github.com/Ibrahim-Adel15/CalculatorGradleApp)

An interactive CLI calculator (Java 17): it reads two numbers from stdin and prints sum, difference, product and quotient. It is **not** a web service — nothing listens on a port.

## Environment

Ubuntu 24.04.4 LTS on WSL2 · Java 17 · Maven · Gradle · Docker 29.1.3 · kubectl + kind · Helm · Ansible
