import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
TIME_WIDTH = 16
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def float_to_q8_8(f):
    """Convert float to Q8.8 fixed-point."""
    return int(f * 256)

def q8_8_to_float(q):
    """Convert Q8.8 fixed-point to float."""
    return q / 256.0

def pack_observation(time_val, color_val):
    """Pack observation into 24-bit format: time[15:0], color[1:0], unused[5:0]."""
    return (time_val & 0xFFFF) | ((color_val & 0x3) << 16)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# INPUT PARSING
# ============================================================================

def parse_color(color_str):
    """Convert color string to numeric encoding."""
    mapping = {'green': 0, 'yellow': 1, 'red': 2}
    return mapping.get(color_str.lower(), 0)

def parse_input(input_str):
    """Parse the input string into test case components."""
    lines = input_str.strip().split('\n')
    
    # First line: T_g T_y T_r
    T_g, T_y, T_r = map(int, lines[0].split())
    
    # Second line: n
    n = int(lines[1])
    
    # Next n lines: observations
    observations = []
    for i in range(n):
        parts = lines[2 + i].split()
        time_val = int(parts[0])
        color_val = parse_color(parts[1])
        observations.append((time_val, color_val))
    
    # Last line: query
    query_parts = lines[2 + n].split()
    query_time = int(query_parts[0])
    query_color = parse_color(query_parts[1])
    
    return T_g, T_y, T_r, observations, query_time, query_color

# ============================================================================
# MAIN TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_traffic_light_probability(dut):
    """Main test for traffic light probability module."""
    
    # Detect module interface
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Define test cases (parsed from inputs)
    test_cases = [
        {
            'input': "4 4 4\n3\n2 green\n18 yellow\n34 red\n5 green",
            'expected': 0.25
        },
        {
            'input': "4 4 4\n4\n2 green\n6 yellow\n10 red\n14 green\n4 red",
            'expected': 0.0
        },
        {
            'input': "6 6 6\n6\n5 green\n6 green\n9 yellow\n12 yellow\n15 red\n19 red\n7 green",
            'expected': 1.0
        }
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, test_case in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test Case {test_idx + 1}")
        cocotb.log.info(f"{'='*60}")
        
        try:
            # Parse input
            T_g, T_y, T_r, observations, query_time, query_color = parse_input(test_case['input'])
            expected_prob = test_case['expected']
            
            # Scale to fit HDL constraints (8-bit durations, 16-bit times)
            # Original constraints are already within 32-bit, but we scale down for HDL
            T_g_scaled = clamp_to_width(T_g, 8)
            T_y_scaled = clamp_to_width(T_y, 8)
            T_r_scaled = clamp_to_width(T_r, 8)
            
            # Clamp observation times to 16-bit
            obs_data = []
            for t, c in observations:
                t_scaled = clamp_to_width(t, 16)
                obs_data.append(pack_observation(t_scaled, c))
            
            # Clamp query time
            query_time_scaled = clamp_to_width(query_time, 16)
            
            # Fill observation inputs (max 8)
            num_obs = len(obs_data)
            for i in range(8):
                port_name = f'obs_{i}'
                if has_signal(dut, port_name):
                    if i < num_obs:
                        getattr(dut, port_name).value = obs_data[i]
                    else:
                        getattr(dut, port_name).value = 0
            
            # Set configuration
            dut.T_g.value = T_g_scaled
            dut.T_y.value = T_y_scaled
            dut.T_r.value = T_r_scaled
            dut.num_obs.value = num_obs
            dut.query_time.value = query_time_scaled
            dut.query_color.value = query_color
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.probability.value):
                raise TestFailure("Result probability is undefined (X/Z)")
            
            result_q8_8 = int(dut.probability.value)
            result_float = q8_8_to_float(result_q8_8)
            
            # Check with tolerance
            tolerance = 0.01  # 1% tolerance for fixed-point
            if abs(result_float - expected_prob) > tolerance:
                raise TestFailure(
                    f"Expected {expected_prob:.4f}, got {result_float:.4f} "
                    f"(diff: {abs(result_float - expected_prob):.4f})"
                )
            
            cocotb.log.info(f"  PASS: Probability = {result_float:.4f} (expected {expected_prob:.4f})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"FINAL RESULTS: {passed}/{passed+failed} tests passed")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
