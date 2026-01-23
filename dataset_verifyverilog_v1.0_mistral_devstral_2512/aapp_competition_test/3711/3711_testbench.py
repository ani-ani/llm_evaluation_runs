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

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
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
async def test_chocolate_cutting(dut):
    """Test chocolate cutting module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, m, k, expected_result, description)
    test_cases = [
        (3, 4, 1, 6, "Sample 1: 3x4 chocolate, 1 cut"),
        (6, 4, 2, 8, "Sample 2: 6x4 chocolate, 2 cuts"),
        (2, 3, 4, 0xFFFFFFFF, "Sample 3: 2x3 chocolate, 4 cuts (impossible)"),
        (10, 10, 2, 30, "10x10 chocolate, 2 cuts"),
        (100, 100, 150, 0xFFFFFFFF, "100x100 chocolate, 150 cuts (impossible)"),
        (2, 2, 2, 1, "2x2 chocolate, 2 cuts"),
        (5, 5, 5, 1, "5x5 chocolate, 5 cuts"),
        (4, 6, 4, 6, "4x6 chocolate, 4 cuts"),
        (1000, 1000, 1000, 500, "1000x1000 chocolate, 1000 cuts"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, k, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Inputs: n={n}, m={m}, k={k}")
        cocotb.log.info(f"  Expected: {expected if expected != 0xFFFFFFFF else -1}")
        
        try:
            # Set inputs
            dut.n.value = n
            dut.m.value = m
            dut.k.value = k
            dut.start.value = 0
            
            # Wait a cycle for inputs to stabilize
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Handle -1 case (0xFFFFFFFF in 32-bit)
            if expected == 0xFFFFFFFF:
                if result != 0xFFFFFFFF:
                    raise TestFailure(f"Expected -1 (0xFFFFFFFF), got {result}")
            else:
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result if result != 0xFFFFFFFF else -1} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
