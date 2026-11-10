# Gacha Village

**▶ Play: https://severance.lol/3/**

Web deploy: `godot --headless --export-release "Web" build/web/index.html` then `scp build/web/* ubuntu@severance.lol:/var/www/severance/3/`

![alt text](image.png)

## Playable room
The main scene (`node_2d.tscn`) is a third-person village survival game, using the custom player character and an over-the-shoulder camera. Start in a warmly lit room, find the foam pistol in the wardrobe, then head outside to defend yourself from two armed villagers patrolling the street. Villagers fire foam pellets, disappear when hit, and respawn after a short delay. The room has collectible fruit, a wall-mounted light switch, enclosing walls and ceiling, and an opening door; across the street lies a panel-housing estate (`district.gd`) laid out after a satellite map of a real Czech sídliště: long five-storey blocks (including the HOME block), eight-storey point towers, a supermarket with a pharmacy, parked cars, footpaths, trees and a quarter of red-roofed family houses, all surrounded by forest. Five of the panel blocks have an enterable ground-floor flat. Each flat has an opening door and a furnished room with Cogito furniture and decorations including a lounge chair, side table, open bookcase, rug, small plant, books, and coffee mug, plus collectible fruit and a wardrobe with a foam pistol.

### Controls
- **WASD**: Move
- **Shift**: Run
- **Space**: Jump
- **Mouse**: Look around (vertical look is inverted by default)
- **E**: Open/close doors, take fruit or the foam pistol, pull/push a wardrobe drawer, or toggle the wall switch while aiming at the object. The pistols only appear when their drawers are open.
- **Q or left mouse button**: Fire a foam pellet with the collected pistol (six shots per magazine)
- **R**: Reload the pistol
- **Health**: The game ends when your health reaches zero; use **Play Again** to restart.
- **Esc**: Release the mouse; click to capture it again
- **Android/mobile**: Use the on-screen joystick to move, drag on the right side to look, and tap **E** to interact. The on-screen buttons also provide jump, run, pistol fire, and reload.
