# Vehicles

A vehicle is ordinary physics: a chassis body on wheel bodies, every wheel on a motorised hinge (docs/HINGES.md), friction between the wheels and the ground. It is **driven like a tank**: the left and the right side get a speed each from throttle and steer, so a turn needs no steering knuckle and the vehicle can spin in place. `sim/vehicle_system.*`.

```lua
local car = vehicle.spawn { x = 40, y = 3.2, z = 52,        -- the centre of the chassis, metres (a little above the ground)
                            heading = 90,                      -- degrees, 0 faces +z, 90 faces +x
                            width = 32, thickness = 6, length = 56,   -- chassis slab in voxels (1/16 m)
                            cab = 24, cab_material = "glass",  -- an open cab over the rear 40 % (posts, back wall, roof), 0 for none
                            wheel_radius = 6, wheel_width = 4, axles = 2,   -- 2 or 3
                            max_speed = 12, torque = 0.7,      -- m/s; fraction of the torque that lifts the whole weight at the rim
                            chassis = "wood", wheel_material = "wood" }
vehicle.drive(car, 1, 0)        -- throttle -1..1, steer -1..1 (positive turns right); stays until the next call
vehicle.enter(car)              -- the player sits in (within about 4 m); the camera follows the seat
vehicle.exit()
vehicle.info(car)               -- { x, y, z, fx, fy, fz (heading), speed (m/s along it), throttle, steer, wheels, occupied } or nil
vehicle.list(); vehicle.seated(); vehicle.remove(car)
```
At most 16 vehicles. A vehicle that falls out of the world is forgotten.

## Driving it (play)
Look at the vehicle (chassis or wheel) and press **E** (`[E] Drive` shows), then **W / S** throttle, **A / D** steer (the left stick works too), **E** to get out (at the side). While seated the player does not walk; the mouse looks around, the camera turns with the chassis. A seated vehicle that is not given input holds still with a brake (on a slope too); after you get out it stays braked until it is driven or entered again (a new one that nobody has touched rolls free).

**In a networked session** every player has a seat of their own (one player per vehicle: `vehicle_enter` of an occupied vehicle does nothing): the actions say which player (`vehicle_enter {id, player}`, `vehicle_exit {player}`, `vehicle_drive {id, throttle, steer, player}`; the host's frame loop overrides the player with the real sender, so nobody drives someone else's seat), the driver's own machine places the camera in the seat (their state goes out as usual, the others see their box in the cab), and a player who leaves frees the seat. The vehicle itself is simulated by everyone from the logged drive commands. Lua's `vehicle.enter` seats player 0.

## What the numbers mean
- The motor torque per wheel is `torque x total mass x g x wheel radius / wheels`: 0.5 climbs about 25 degrees, 0.7 is the default, 0.9 climbs a steeper hill and spins the wheels on the flat. The commands are eased before they reach the motors (full throttle takes about 0.25 s, steering 0.17 s) and a fast vehicle steers up to 35 % less (so a key press is not a jerk and a tank turn at speed is not a skid); `vehicle.info` and the keys still show the commanded values. Friction comes from the materials (all 0.6 now; a "rubber" row in `materials.csv` with a higher friction grips better).
- A driven or occupied vehicle never falls asleep; an empty one sleeps like any body and is not welded back (it is `owned`).
- Blasts push it but do not carve it (the chassis and the wheels are not carvable).

## Determinism and replays
The vehicle's state is the last drive command and the seat; both are set by the logged actions `vehicle_drive`, `vehicle_enter`, `vehicle_exit` (the keys send them when the input changes), or by the script, which runs again in a replay. It is part of the session hash when any exists. A recording with a vehicle replays to its hash (`tests/test_vehicles.cpp`, and by hand with a script that drives it).

## Not built
Steering knuckles (Ackermann), suspension (the wheels are rigid on their axles: a bumpy ride over voxel steps), gears, passengers beyond the first seat, riding in a networked session, boats and aircraft, damage. A vehicle model from a `.vxm` instead of the built-in slab and cab is the next step.
