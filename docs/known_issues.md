# Known issues to fix

Failing checks that are not caused by recent changes (they fail the same way on earlier commits). The checks are throwaway
headless scripts, not committed; the scenarios are what to re-test.

## inventory_click_test: 2 failures

1. **"world click picks the key up onto the cursor."** Clicking a key on the floor does not leave it on the cursor. Likely
   expected: since a plain pick-up of a key stows it in the first living hero's backpack ("Key picked up!"), the test's
   assumption is out of date. Check by hand that a key goes to a pack and, with every pack full, stays on the cursor; then fix or
   update the check.
2. **"held icon is re-placed at the mouse every frame while paused."** The item on the cursor does not follow the mouse each
   frame while the inventory has the game paused. Not confirmed as a real bug in play: check by hand (hold an item, open the
   inventory, move the mouse) before changing code.
