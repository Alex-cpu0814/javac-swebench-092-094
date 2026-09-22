# Case 094 verification

Schema-3.0 verification separates clean-image construction from candidate
runs. `builds/` records the Docker build and no-Fix image audit; `runs/`
records runtime patch injection, build, tests, and grading; `controls/` holds
negative and tampering controls. The formal gold run is `case-094-v3-gold5`
with F2P 1/1 and P2P 95/95.
