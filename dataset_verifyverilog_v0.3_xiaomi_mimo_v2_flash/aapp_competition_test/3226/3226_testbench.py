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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

MAX_NODES = 8
MAX_EDGES = 8
MAX_EXITS = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 3000  # enough for Floyd + Dijkstra

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_escape_speed(dut):
    """Test the escape_speed module with three test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (n, m, e, edges, exits, b, p, expected)
    # nodes are 1-indexed in input, convert to 0-index for DUT
    # edges: list of (a, b, l) 0-indexed
    # exits: list of 0-indexed
    test_cases = [
        # Case 1: IMPOSSIBLE
        (
            3, 2, 1,
            [(0,1,7), (1,2,8)],
            [0],  # exits
            2, 1,  # b, p
            "IMPOSSIBLE"
        ),
        # Case 2: 74.6666666667
        (
            3, 2, 1,
            [(0,1,7), (1,2,8)],
            [0],
            1, 2,  # b, p
            "74.6666666667"
        ),
        # Case 3: 137.142857143
        (
            4, 4, 2,
            [(0,3,1), (0,2,4), (2,3,10), (1,2,30)],
            [0,1],  # exits
            2, 3,  # b, p
            "137.142857143"
        ),
    ]
    
    for case_idx, (n, m, e, edges, exits, b, p, expected) in enumerate(test_cases):
        dut._log.info(f"\nTest case {case_idx+1}: n={n}, m={m}, e={e}")
        
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        dut.e.value = e
        dut.b.value = b
        dut.p.value = p
        
        # Clear all edge valid flags
        for i in range(MAX_EDGES):
            setattr(dut, f'edge_valid{i}', 0)
        
        # Set edges
        for i, (a, b_node, l) in enumerate(edges):
            setattr(dut, f'edge_a{i}', a)
            setattr(dut, f'edge_b{i}', b_node)
            setattr(dut, f'edge_l{i}', l)
            setattr(dut, f'edge_valid{i}', 1)
        
        # Clear all exits
        for i in range(MAX_EXITS):
            setattr(dut, f'exit{i}', 0)
        
        # Set exits
        for i, ex in enumerate(exits):
            setattr(dut, f'exit{i}', ex)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Read outputs
        if not is_value_defined(dut.impossible.value):
            raise TestFailure("impossible signal undefined")
        imp = int(dut.impossible.value)
        
        if not is_value_defined(dut.speed_q16.value):
            raise TestFailure("speed_q16 undefined")
        speed_raw = int(dut.speed_q16.value)
        
        if expected == "IMPOSSIBLE":
            if imp != 1:
                raise TestFailure(f"Case {case_idx+1}: expected IMPOSSIBLE, got speed={speed_raw}")
            dut._log.info(f"  PASS: IMPOSSIBLE detected")
        else:
            if imp == 1:
                raise TestFailure(f"Case {case_idx+1}: expected speed {expected}, got IMPOSSIBLE")
            # Convert Q16.16 to float
            speed_float = speed_raw / 65536.0
            expected_float = float(expected)
            if abs(speed_float - expected_float) > 1e-6:
                raise TestFailure(f"Case {case_idx+1}: expected {expected_float}, got {speed_float}")
            dut._log.info(f"  PASS: speed = {speed_float:.10f}")
        
        # Wait one cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")
