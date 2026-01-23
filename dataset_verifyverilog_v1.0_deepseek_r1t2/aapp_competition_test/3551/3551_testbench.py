import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Simulation model for expected moves
def simulate_two_jug_moves(cap1, cap2, T):
    """Simulate moves for two jug problem"""
    if T > cap1 + cap2:
        return ["impossible"]
    
    # Check if T is achievable: T must be multiple of gcd(cap1, cap2)
    def gcd(a, b):
        while b:
            a, b = b, a % b
        return a
    
    if T % gcd(cap1, cap2) != 0:
        return ["impossible"]
    
    # BFS to find sequence
    from collections import deque
    
    # State: (amount1, amount2)
    start = (0, 0)
    parent = {}
    action = {}
    queue = deque([start])
    parent[start] = None
    
    found = None
    while queue:
        a1, a2 = queue.popleft()
        
        if a1 == T or a2 == T:
            found = (a1, a2)
            break
        
        # Generate next states
        next_states = []
        
        # Fill bottle1
        if a1 < cap1:
            next_states.append(((cap1, a2), ("fill", 1, 0)))
        # Fill bottle2
        if a2 < cap2:
            next_states.append(((a1, cap2), ("fill", 2, 0)))
        # Empty bottle1
        if a1 > 0:
            next_states.append(((0, a2), ("discard", 1, 0)))
        # Empty bottle2
        if a2 > 0:
            next_states.append(((a1, 0), ("discard", 2, 0)))
        # Transfer bottle1 to bottle2
        if a1 > 0 and a2 < cap2:
            pour = min(a1, cap2 - a2)
            next_states.append(((a1 - pour, a2 + pour), ("transfer", 1, 2)))
        # Transfer bottle2 to bottle1
        if a2 > 0 and a1 < cap1:
            pour = min(a2, cap1 - a1)
            next_states.append(((a1 + pour, a2 - pour), ("transfer", 2, 1)))
        # Transfer bottle1 to mix
        if a1 > 0:
            next_states.append(((0, a2), ("transfer", 1, 0)))
        # Transfer bottle2 to mix
        if a2 > 0:
            next_states.append(((a1, 0), ("transfer", 2, 0)))
        
        for new_state, act in next_states:
            if new_state not in parent:
                parent[new_state] = (a1, a2)
                action[new_state] = act
                queue.append(new_state)
    
    if found is None:
        return ["impossible"]
    
    # Reconstruct path
    moves = []
    state = found
    while parent[state] is not None:
        moves.append(action[state])
        state = parent[state]
    
    moves.reverse()
    
    # Convert to output strings
    result = []
    for move in moves:
        op, src, dst = move
        if op == "fill":
            result.append(f"fill {src}")
        elif op == "discard":
            result.append(f"discard {src}")
        elif op == "transfer":
            result.append(f"transfer {src} {dst}")
    
    return result

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_dino_ice_cream(dut):
    """Test the dino_ice_cream module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (bottle1_cap, bottle2_cap, target, description)
    test_cases = [
        (7, 8, 10, "Example 1: 7 and 8 liter bottles, target 10"),
        (2, 4, 3, "Example 2: 2 and 4 liter bottles, target 3 (impossible)"),
        (3, 5, 4, "Possible: 3 and 5 liter bottles, target 4"),
        (6, 10, 2, "Simple: 6 and 10 liter bottles, target 2"),
        (1, 1, 1, "Trivial: 1 liter bottles, target 1"),
        (5, 7, 8, "Another possible case"),
        (4, 9, 6, "Another test"),
    ]
    
    for cap1, cap2, target, description in test_cases:
        dut._log.info(f"\nTest: {description}")
        dut._log.info(f"  Bottle1={cap1}L, Bottle2={cap2}L, Target={target}L")
        
        # Get expected moves
        expected = simulate_two_jug_moves(cap1, cap2, target)
        dut._log.info(f"  Expected: {expected}")
        
        # Set inputs
        dut.bottle1_cap.value = cap1
        dut.bottle2_cap.value = cap2
        dut.target.value = target
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect actual moves
        actual = []
        timeout = 0
        
        while timeout < MAX_CYCLES:
            await RisingEdge(dut.clk)
            timeout += 1
            
            if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                op_code = int(dut.op.value)
                src = int(dut.src.value)
                dst = int(dut.dst.value)
                
                if op_code == 0:  # fill
                    move = f"fill {src}"
                elif op_code == 1:  # discard
                    move = f"discard {src}"
                elif op_code == 2:  # transfer
                    move = f"transfer {src} {dst}"
                elif op_code == 3:  # impossible
                    move = "impossible"
                elif op_code == 4:  # done
                    break
                else:
                    raise TestFailure(f"Unknown op code: {op_code}")
                
                actual.append(move)
                dut._log.info(f"  Move: {move}")
            
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        if timeout >= MAX_CYCLES:
            raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Compare
        if actual != expected:
            raise TestFailure(f"Mismatch: expected {expected}, got {actual}")
        else:
            dut._log.info(f"  PASS")
    
    dut._log.info("\nAll tests passed!")