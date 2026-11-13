# Multiplayer Latency Simulation

A 2D multiplayer networking simulation built with **Godot 4** and **GDScript** to demonstrate the effects of network latency and compare movement with and without client-side prediction.

## Features

- **Server-authoritative movement:** The server validates player actions and maintains the authoritative game state.
- **Client-side prediction:** Players move immediately without waiting for server confirmation.
- **Server reconciliation:** Predicted positions are corrected using server acknowledgments and input replay.
- **Simulated network latency:** Configurable one-way latency.
- **Collision detection:** Server-side and client-side collision prediction.
- **Door synchronization:** Simulates delayed environment updates between server and clients.
- **Adaptive correction:** Small errors are ignored visually, medium errors are smoothed, and large errors trigger snapping.
- **Debug dashboard:** Displays latency, player positions, pending inputs, acknowledgments, and correction errors.

## Requirements

- Godot 4.x
- No external dependencies

## Installation

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/MultiplayerLatencySimulation.git
cd MultiplayerLatencySimulation
```

Open `project.godot` in Godot and press **F5** to run the simulation.

## Controls

| Key | Action |
|---|---|
| W | Move up |
| A | Move left |
| S | Move down |
| D | Move right |
| Space | Open/close the server-controlled door |

## Simulation

The application displays two clients:

- **Left — Without Prediction:** Movement is displayed only after server confirmation.
- **Right — With Prediction:** Movement is predicted locally and reconciled with authoritative server updates.

Both clients experience the same simulated network latency.

A separate server indicator displays the authoritative door state.

## Project Structure

```text
scenes/          Godot scenes
scripts/
├── client/      Client-related modules
├── server/      Server and network simulation
├── shared/      Shared movement logic
└── ui/          Main simulation and interface
assets/          Game assets
tests/           Tests
```

## Purpose

This project demonstrates how client-side prediction and server reconciliation improve responsiveness in multiplayer games while maintaining server authority under network latency.

## License

No license specified.
