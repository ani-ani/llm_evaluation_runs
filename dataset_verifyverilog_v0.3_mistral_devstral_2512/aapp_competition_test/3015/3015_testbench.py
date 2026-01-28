import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_NODES = 8
MAX_EDGES = 16
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_hamster_path(dut):
    """Main test function for hamster_path module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: input string and expected output string
    test_cases = [
        ("4 5 0 3\n0 1 1\n1 2 2\n2 0 4\n2 3 1\n2 3 3\n", "11\n"),
        ("5 5 0 4\n0 1 1\n1 2 1\n2 3 1\n3 0 1\n2 4 1\n", "infinity\n"),
        ("2 1 0 1\n0 1 2\n", "2\n"),
        ("3 3 1 2\n0 1 1\n1 0 1\n1 2 1\n", "infinity\n"),
        ("3 2 0 1\n0 2 3\n2 0 3\n", "infinity\n"),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (input_str, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {input_str.split(chr(10))[0]} ...")
        
        # Parse input
        lines = input_str.strip().split('\n')
        header = lines[0].split()
        n = int(header[0])
        m = int(header[1])
        s = int(header[2])
        t = int(header[3])
        
        edges = []
        for i in range(m):
            parts = lines[1+i].split()
            a = int(parts[0])
            b = int(parts[1])
            w = int(parts[2])
            edges.append((a, b, w))
        
        # Prepare arrays
        src_list = [0] * MAX_EDGES
        dst_list = [0] * MAX_EDGES
        weight_list = [0] * MAX_EDGES
        
        for i, (a, b, w) in enumerate(edges):
            if i >= MAX_EDGES:
                cocotb.log.warning(f"Too many edges ({m}), truncating to {MAX_EDGES}")
                break
            src_list[i] = a
            dst_list[i] = b
            weight_list[i] = w
        
        # Set inputs
        dut.s.value = s
        dut.t.value = t
        dut.num_edges.value = m
        
        # Assign edge arrays element by element
        for i in range(MAX_EDGES):
            if has_signal(dut, 'edge_src'):
                # Assuming edge_src is an array
                if i < m:
                    dut.edge_src[i].value = src_list[i]
                    dut.edge_dst[i].value = dst_list[i]
                    dut.edge_weight[i].value = weight_list[i]
                else:
                    dut.edge_src[i].value = 0
                    dut.edge_dst[i].value = 0
                    dut.edge_weight[i].value = 0
            else:
                # If individual ports exist (edge_src_0, edge_src_1, ...)
                if has_signal(dut, f'edge_src_{i}'):
                    if i < m:
                        getattr(dut, f'edge_src_{i}').value = src_list[i]
                        getattr(dut, f'edge_dst_{i}').value = dst_list[i]
                        getattr(dut, f'edge_weight_{i}').value = weight_list[i]
                    else:
                        getattr(dut, f'edge_src_{i}').value = 0
                        getattr(dut, f'edge_dst_{i}').value = 0
                        getattr(dut, f'edge_weight_{i}').value = 0
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read results
        if not is_value_defined(dut.infinite.value):
            raise TestFailure(f"Infinite flag undefined")
        infinite = int(dut.infinite.value)
        
        if infinite == 0:
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result undefined when finite")
            result = int(dut.result.value)
        else:
            result = None
        
        # Parse expected
        expected_infinite = 0
        expected_result = None
        if "infinity" in expected_str:
            expected_infinite = 1
        else:
            expected_result = int(expected_str.strip())
        
        # Verify
        if infinite != expected_infinite:
            cocotb.log.error(f"Test {idx+1} FAIL: infinite flag mismatch. Expected {expected_infinite}, got {infinite}")
            failed += 1
        elif expected_infinite == 0 and result != expected_result:
            cocotb.log.error(f"Test {idx+1} FAIL: result mismatch. Expected {expected_result}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"Test {idx+1} PASS")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")