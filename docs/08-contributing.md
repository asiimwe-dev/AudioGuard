# Contributing to AudioGuard

Thank you for your interest in contributing to AudioGuard. This project aims to provide high-fidelity audio watermarking solutions, and we value the contributions of the community to help us achieve this goal.

## Table of Contents
- [Contributing to AudioGuard](#contributing-to-audioguard)
  - [Table of Contents](#table-of-contents)
  - [Code of Conduct](#code-of-conduct)
    - [Our Pledge](#our-pledge)
    - [Our Standards](#our-standards)
    - [Enforcement](#enforcement)
  - [Getting Started](#getting-started)
  - [How to Contribute](#how-to-contribute)
    - [Reporting Bugs](#reporting-bugs)
    - [Suggesting Enhancements](#suggesting-enhancements)
  - [Pull Request Process](#pull-request-process)
  - [Coding Standards](#coding-standards)
    - [Python (Backend)](#python-backend)
    - [Dart/Flutter (Frontend)](#dartflutter-frontend)
  - [Testing Requirements](#testing-requirements)
    - [Running Tests](#running-tests)
  - [Security Policy](#security-policy)

---

## Code of Conduct

### Our Pledge
In the interest of fostering an open and welcoming environment, we as contributors and maintainers pledge to making participation in our project and our community a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards
Examples of behavior that contributes to creating a positive environment include:
* Using welcoming and inclusive language
* Being respectful of differing viewpoints and experiences
* Gracefully accepting constructive criticism
* Focusing on what is best for the community
* Showing empathy towards other community members

Examples of unacceptable behavior by participants include:
* The use of sexualized language or imagery and unwelcome sexual attention or advances
* Trolling, insulting/derogatory comments, and personal or political attacks
* Public or private harassment
* Publishing others' private information, such as a physical or electronic address, without explicit permission
* Other conduct which could reasonably be considered inappropriate in a professional setting

### Enforcement
Maintainers are responsible for clarifying the standards of acceptable behavior and are expected to take appropriate and fair corrective action in response to any instances of unacceptable behavior.

---

## Getting Started

Before you begin contributing, please ensure you have a working development environment.

1.  **Fork the repository** on GitHub.
2.  **Clone your fork** locally:
    ```bash
    git clone https://github.com/your-username/AudioGuard.git
    cd AudioGuard
    ```
3.  **Set up the environment**:
    *   **Backend**: Follow the [Backend Guide](06-backend-guide.md).
    *   **Frontend**: Follow the [Frontend Guide](05-frontend-guide.md).
4.  **Run the tests** to ensure your environment is correctly configured:
    ```bash
    cd backend
    python -m pytest tests/
    ```

---

## How to Contribute

### Reporting Bugs
If you find a bug, please open a GitHub issue with a descriptive title and provide:
*   A clear summary of the issue.
*   Steps to reproduce the behavior.
*   The expected vs. actual outcome.
*   Relevant logs or screenshots.

### Suggesting Enhancements
We welcome ideas for new features or improvements. When suggesting an enhancement:
*   Verify that it hasn't already been suggested.
*   Describe the use case and why this feature would be valuable.
*   Provide any implementation details if you have them.

---

## Pull Request Process

1.  **Create a branch** for your changes:
    ```bash
    git checkout -b feature/your-feature-name
    ```
2.  **Commit your changes** using clear, descriptive messages following the [Conventional Commits](https://www.conventionalcommits.org/) specification.
3.  **Update documentation** to reflect any changes in functionality or API.
4.  **Add/update tests** to cover your changes.
5.  **Push to your fork** and submit a Pull Request (PR) to the `main` branch.
6.  **Maintainers will review** your PR. Please be responsive to feedback and requested changes.

---

## Coding Standards

### Python (Backend)
*   Adhere to **PEP 8** style guidelines.
*   Use **Type Hints** for all function signatures.
*   Include descriptive docstrings (Google style preferred).
*   Maintain modularity and follow SOLID principles.

### Dart/Flutter (Frontend)
*   Follow the official [Dart Style Guide](https://dart.dev/guides/language/analysis-options).
*   Use Riverpod for state management consistently.
*   Ensure widget components are reusable and well-documented.

---

## Testing Requirements

We maintain a high standard for test coverage. Every pull request must:
*   Pass all existing automated tests.
*   Include new tests for any added functionality.
*   Maintain or increase the overall project test coverage.

### Running Tests
```bash
# Backend
cd backend && python -m pytest tests/

# Frontend
cd frontend && flutter test
```

---

## Security Policy

If you discover a potential security vulnerability, please do **not** open a public issue. Instead, email us directly at Email: (gilbertasiimwe00@gmail.com). We will work with you to address the issue promptly.

---
AudioGuard Contribution Guidelines | Version 1.0.0
