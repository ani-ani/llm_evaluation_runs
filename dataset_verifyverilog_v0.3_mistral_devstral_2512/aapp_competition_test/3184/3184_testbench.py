import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 8  # Number of walls
K = 8  # Number of cameras
DATA_WIDTH = 3  # Bits for a_i, b_i (since N <= 8)
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000  # Enough for BFS

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_camera_inputs(dut, a_list, b_list):
    """Write a_i and b_i values to DUT. Handles individual ports."""
    for i in range(K):
        a_val = a_list[i] if i < len(a_list) else 0
        b_val = b_list[i] if i < len(b_list) else 0
        
        # Try individual ports a0..a7, b0..b7
        a_port = f'a{i}'
        b_port = f'b{i}'
        
        if has_signal(dut, a_port):
            getattr(dut, a_port).value = clamp_to_width(a_val, DATA_WIDTH)
        else:
            # Try indexed array: a[i]
            try:
                dut.a[i].value = clamp_to_width(a_val, DATA_WIDTH)
            except (AttributeError, TypeError):
                raise TestFailure(f"Cannot find port for a{i}")
        
        if has_signal(dut, b_port):
            getattr(dut, b_port).value = clamp_to_width(b_val, DATA_WIDTH)
        else:
            try:
                dut.b[i].value = clamp_to_width(b_val, DATA_WIDTH)
            except (AttributeError, TypeError):
                raise TestFailure(f"Cannot find port for b{i}")

async def read_result(dut):
    """Read result and done signals."""
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    result = int(dut.result.value)
    done = is_value_defined(dut.done.value) and int(dut.done.value) == 1
    return result, done

async def reset_dut(dut):
    """Reset sequence."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_camera_cover(dut):
    """Test the CameraCover module with three scenarios."""
    
    # Detect interface type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (a_list, b_list, expected_result, description)
    # a_list and b_list are lists of length K (fill unused with 0)
    test_cases = [
        # Test 1: 7 cameras, minimal 3
        (
            [1, 4, 6, 8, 2, 5, 7, 0],  # a_i
            [4, 6, 8, 3, 5, 7, 2, 0],  # b_i
            3,
            "7 cameras, minimal 3"
        ),
        # Test 2: 2 cameras, impossible
        (
            [8, 5, 0, 0, 0, 0, 0, 0],
            [3, 7, 0, 0, 0, 0, 0, 0],
            0,
            "2 cameras, impossible"
        ),
        # Test 3: 2 cameras, minimal 2
        (
            [1, 5, 0, 0, 0, 0, 0, 0],
            [4, 8, 0, 0, 0, 0, 0, 0],
            2,
            "2 cameras, minimal 2"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_vals, b_vals, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Write camera inputs
            await write_camera_inputs(dut, a_vals, b_vals)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result, _ = await read_result(dut)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
