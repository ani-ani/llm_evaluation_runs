import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# PROBLEM-SPECIFIC HELPERS
# ============================================================================

def encode_grid_4x4(grid_lines):
    """Encode 4x4 grid to 16-bit bitmap (1=obstacle)."""
    bits = 0
    for y in range(4):
        for x in range(4):
            if y < len(grid_lines) and x < len(grid_lines[y]):
                if grid_lines[y][x] == '#':
                    bits |= 1 << (y * 4 + x)
            # Pad with obstacles if out of bounds
            else:
                bits |= 1 << (y * 4 + x)
    return bits

def find_position(grid_lines, char):
    """Find position of S or G in grid, return (x,y)."""
    for y, row in enumerate(grid_lines):
        for x, c in enumerate(row):
            if c == char:
                return (x, y)
    return (0, 0)

def encode_commands(cmd_str, max_cmds=8):
    """Encode command string to bits, return (encoded_value, length)."""
    mapping = {'L': 0, 'R': 1, 'U': 2, 'D': 3}
    encoded = 0
    length = min(len(cmd_str), max_cmds)
    for i in range(length):
        encoded |= mapping[cmd_str[i]] << (i * 2)
    return encoded, length

def scale_to_4x4(original_lines):
    """Scale or pad grid to exactly 4x4."""
    result = []
    for i in range(4):
        if i < len(original_lines):
            row = original_lines[i][:4].ljust(4, '.')
        else:
            row = '....'
        result.append(row)
    return result

# ============================================================================
# REFERENCE IMPLEMENTATION (Python)
# ============================================================================

def compute_min_changes_python(grid, start, goal, commands):
    """Reference implementation using BFS."""
    from collections import deque
    
    H, W = 4, 4
    
    # Cost table: (x, y, cmd_idx) -> min changes
    INF = 15
    cost = {}
    
    # Directions
    dirs = {'L': (-1, 0), 'R': (1, 0), 'U': (0, -1), 'D': (0, 1)}
    
    # BFS queue: (x, y, cmd_idx, changes)
    q = deque()
    start_state = (start[0], start[1], 0)
    cost[start_state] = 0
    q.append(start_state)
    
    while q:
        x, y, cmd_idx = q.popleft()
        current_cost = cost[(x, y, cmd_idx)]
        
        # Check if goal reached
        if (x, y) == goal:
            return current_cost
        
        # Explore operations
        # 1. Execute command
        if cmd_idx < len(commands):
            cmd = commands[cmd_idx]
            dx, dy = dirs[cmd]
            nx, ny = x + dx, y + dy
            # Check bounds and obstacles
            if 0 <= nx < W and 0 <= ny < H and grid[ny][nx] != '#':
                new_state = (nx, ny, cmd_idx + 1)
                if cost.get(new_state, INF) > current_cost:
                    cost[new_state] = current_cost
                    q.append(new_state)
            else:
                # Command ignored (invalid move)
                new_state = (x, y, cmd_idx + 1)
                if cost.get(new_state, INF) > current_cost:
                    cost[new_state] = current_cost
                    q.append(new_state)
        
        # 2. Delete command
        if cmd_idx < len(commands):
            new_state = (x, y, cmd_idx + 1)
            if cost.get(new_state, INF) > current_cost + 1:
                cost[new_state] = current_cost + 1
                q.append(new_state)
        
        # 3. Insert command
        for cmd in ['L', 'R', 'U', 'D']:
            dx, dy = dirs[cmd]
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and grid[ny][nx] != '#':
                new_state = (nx, ny, cmd_idx)
                if cost.get(new_state, INF) > current_cost + 1:
                    cost[new_state] = current_cost + 1
                    q.append(new_state)
    
    return INF  # No path found

# ============================================================================
# MAIN TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_robot_fixer(dut):
    """Main test function for robot_fixer module."""
    
    # Configuration
    CLK_PERIOD_NS = 10
    H = 4
    W = 4
    MAX_CMDS = 8
    
    # Detect interface
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset sequence
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases (adapted to 4x4 grid)
    # Each test case: (grid_lines, commands, expected_changes)
    test_cases = [
        {
            'name': 'Sample 1 (simplified)',
            'grid': ['S..', '.#.', '..G'],
            'commands': 'DRRDD',
            'expected': 1
        },
        {
            'name': 'Sample 2 (simplified)',
            'grid': ['....', '.GS.', '....'],  # Scaled version
            'commands': 'LDLDLLDR',
            'expected': 1
        },
        {
            'name': 'Sample 3 (simplified)',
            'grid': ['....', '.G#.', '..S.'],  # Scaled version
            'commands': 'LDLDLLDR',
            'expected': 2
        },
        {
            'name': 'No changes needed',
            'grid': ['S..G', '....', '....', '....'],
            'commands': 'R',
            'expected': 0
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test {i+1}: {tc['name']}")
        dut._log.info(f"Commands: {tc['commands']}")
        
        # Scale grid to 4x4
        grid_scaled = scale_to_4x4(tc['grid'])
        
        # Find positions
        start_pos = find_position(grid_scaled, 'S')
        goal_pos = find_position(grid_scaled, 'G')
        
        # Encode
        grid_encoded = encode_grid_4x4(grid_scaled)
        cmd_encoded, cmd_len = encode_commands(tc['commands'], MAX_CMDS)
        
        dut._log.info(f"Grid (4x4): {grid_scaled}")
        dut._log.info(f"Start: {start_pos}, Goal: {goal_pos}")
        dut._log.info(f"Grid bits: {grid_encoded:016b}")
        dut._log.info(f"Cmd encoded: {cmd_encoded:016b}, len={cmd_len}")
        
        # Assign inputs
        if has_signal(dut, 'grid'):
            dut.grid.value = grid_encoded
        
        if has_signal(dut, 'start_x'):
            dut.start_x.value = start_pos[0]
            dut.start_y.value = start_pos[1]
            dut.goal_x.value = goal_pos[0]
            dut.goal_y.value = goal_pos[1]
        
        if has_signal(dut, 'commands'):
            dut.commands.value = cmd_encoded
        
        if has_signal(dut, 'cmd_len'):
            dut.cmd_len.value = cmd_len
        
        # Start computation
        if is_sequential:
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                await RisingEdge(dut.clk)
            
            # Wait for done
            timeout = 0
            while timeout < 1000:
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
                timeout += 1
            else:
                raise TestFailure(f"Timeout waiting for done")
        else:
            # Combinational - wait for propagation
            await Timer(500, units='ns')
        
        # Read result
        if not is_value_defined(dut.min_changes.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.min_changes.value)
        expected = tc['expected']
        
        dut._log.info(f"Result: {result}, Expected: {expected}")
        
        if result == expected:
            dut._log.info(f"✓ PASS")
            passed += 1
        else:
            dut._log.error(f"✗ FAIL: Expected {expected}, got {result}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
