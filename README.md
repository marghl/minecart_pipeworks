# Minecart Hopper – Pipeworks Integration

Small compatibility mod for `joe7575/minecart` and `mt-mods/pipeworks`.
It does not modify either upstream mod.

## Behaviour

- Pipeworks tubes can insert items into the Minecart Hopper's four-slot buffer.
- Pipeworks injectors/filter tubes can extract items from that buffer.
- A Minecart above the Hopper is unloaded into the buffer when the Hopper's
  normal output cannot accept the cargo.
- The Hopper continues to move up to four items every two seconds, as before.

Typical loading setup:

    chest -> injector/tube -> Minecart Hopper -> Minecart

Typical unloading setup:

    Minecart -> Minecart Hopper -> injector/tube -> chest

The Hopper's existing orientation still determines its normal output side.

