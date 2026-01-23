import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4       # N, M, K are 4-bit
RESULT_WIDTH = 32
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
async def test_combinatorial(dut):
    """Test the combinatorial module."""
    
    # Detect if sequential (has clk)
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Test cases: (N, M, K, expected)
    # N, M, K are integers <= 8
    test_cases = [
        (2, 2, 2, 3),    # 2 types, 2 copies each, choose 2 => 3 ways
        (2, 1, 2, 1),    # 2 types, 1 copy each, choose 2 => 1 way
        (3, 3, 3, 10),   # example
        (1, 5, 3, 1),    # 1 type, 5 copies, choose 3 => 1 way
        (3, 1, 2, 3),    # 3 types, 1 copy each, choose 2 => C(3,2)=3
        (3, 1, 0, 1),    # choose 0 => 1 way
        (0, 0, 0, 1),    # edge: N=0? Not per spec but handle
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, M, K, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}, M={M}, K={K} -> expected={expected}")
        
        try:
            # Assign inputs
            if has_signal(dut, 'N'):
                dut.N.value = clamp_to_width(N, DATA_WIDTH)
            if has_signal(dut, 'M'):
                dut.M.value = clamp_to_width(M, DATA_WIDTH)
            if has_signal(dut, 'K'):
                dut.K.value = clamp_to_width(K, DATA_WIDTH)
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result is undefined (X/Z)")
                result = int(dut.result.value)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
                result = int(dut.result.value)
            
            # Compare
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
