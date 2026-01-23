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
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_tree_path(dut):
    """Test tree_path module with sample cases."""
    
    # Configuration
    DATA_WIDTH = 4
    PARENT_WIDTH = 3
    MAX_N = 8
    MOD = 11092019
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Helper functions for array access
    async def write_labels(labels):
        for i in range(MAX_N):
            if i < len(labels):
                val = clamp_to_width(labels[i], DATA_WIDTH)
            else:
                val = 0
            if has_signal(dut, f'label_{i}'):
                getattr(dut, f'label_{i}').value = val
            else:
                raise TestFailure(f"Signal label_{i} not found")
    
    async def write_parents(parents):
        # parents array: index 0 is dummy, index 1..7 are used
        for i in range(1, MAX_N):
            if i < len(parents):
                val = clamp_to_width(parents[i], PARENT_WIDTH)
            else:
                val = 0
            if has_signal(dut, f'parent_{i}'):
                getattr(dut, f'parent_{i}').value = val
            else:
                raise TestFailure(f"Signal parent_{i} not found")
    
    async def reset_dut():
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    async def start_computation():
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    async def wait_for_done(max_cycles=100):
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
        raise TestFailure("Timeout: done not asserted")
    
    # Test cases: (N, labels, parents, expected_L, expected_M)
    test_cases = [
        (5, [3,3,3,3,3], [0,1,2,3,4], 5, 1),  # Sample 1
        (5, [4,3,2,1,0], [0,1,2,3,4], 1, 5),  # Sample 2
        (4, [1,5,3,6], [0,1,2,3], 3, 2),      # Sample 3
        (6, [1,2,3,4,5,6], [0,1,1,1,1,1], 2, 5),  # Additional test
    ]
    
    passed = 0
    failed = 0
    
    for idx, (N, labels, parents, exp_L, exp_M) in enumerate(test_cases):
        dut._log.info(f"Running test {idx+1}: N={N}, labels={labels}, parents={parents}")
        
        try:
            # Reset
            await reset_dut()
            
            # Write inputs
            await write_labels(labels)
            await write_parents(parents)
            
            # Set N
            dut.N.value = N
            
            # Start computation
            await start_computation()
            
            # Wait for done
            await wait_for_done()
            
            # Read outputs
            if not is_value_defined(dut.result_L.value) or not is_value_defined(dut.result_M.value):
                raise TestFailure("Output is undefined (X/Z)")
            
            result_L = int(dut.result_L.value)
            result_M = int(dut.result_M.value)
            
            # Verify
            if result_L != exp_L:
                raise TestFailure(f"Length mismatch: expected {exp_L}, got {result_L}")
            if result_M != exp_M:
                raise TestFailure(f"Count mismatch: expected {exp_M}, got {result_M}")
            
            dut._log.info(f"  PASS: L={result_L}, M={result_M}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
