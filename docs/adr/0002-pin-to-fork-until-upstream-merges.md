# Pin trex to a KittyBrowser commit on the user's fork until upstream merges it

ADR-0001 builds trex on stock KittyBrowser and sends changes to kb upstream. Three such changes are ready but not upstream yet: the trackpad scroll step (ticket 05), keeping a swipe to one axis and stopping the page bouncing at its ends (ticket 09), and `kb ctl` / `kb mcp` reaching the kb beside the caller in Rex (ticket 08). The user wants them now, and the upstream pull requests wait until the user says to open them. So, as a temporary exception to ADR-0001, trex pins a commit on the user's fork `abhishekmmgn/trex-browser`: branch `trex-pin`, which is `scroll-quality` (05 and 09) with `kb-targets-callers-pane` (08) merged in. The pin check wants that repo and that commit in cargo's install record. The same commit installed from another repo doesn't count.

## Scope

- Only the pin moves. trex still uses kb only from outside, through its flags, `kb list`, `kb ctl` and its profile layout, and the work-arounds in trex (such as `bin/trex ctl`) stay.
- The fork carries only these changes. Each stays on its own branch (`trackpad-scroll-delta`, `scroll-quality`, `kb-targets-callers-pane`), so each can become its own upstream pull request. `trex-pin` only combines them. Nothing else goes on the fork, and its `main` stays upstream's.
- Repo and commit live in `lua/trex/pin.lua`. `bin/trex setup` installs them with `cargo install --git <fork> --rev <commit> --locked --force`, and offers to replace any other kb, including upstream's.

## Exit

When the user agrees, open the upstream pull requests from the separate branches. Once upstream has merged them, pin `graiz/kittybrowser` at a commit that contains them, mark this ADR superseded, and stop updating `trex-pin`. If upstream declines one, ADR-0001's "fork only if blocked" applies, and that needs a decision of its own.
