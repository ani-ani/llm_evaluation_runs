import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
STOCK_WIDTH = 4
F_WIDTH = 4
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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_max_profit(dut):
    """Test the max_profit module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (f, p, m, s for each position, expected profit)
    # f values are 1-based (as per problem)
    test_cases = [
        # Sample 1:
        {
            'f': [1, 2, 3],
            'p': [2, 3, 4],
            'm': [3, 4, 5],
            's': [1, 1, 1],
            'expected': 3
        },
        # Sample 2:
        {
            'f': [2, 3, 1],
            'p': [2, 1, 9],
            'm': [3, 5, 4],
            's': [8, 6, 7],
            'expected': 39
        },
        # Sample 3:
        {
            'f': [5, 1, 2, 2, 1],
            'p': [9, 1, 3, 2, 4],
            'm': [2, 7, 6, 9, 5],
            's': [2, 4, 3, 6, 1],
            'expected': 22
        },
    ]
    
    for i, test in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: {test}")
        
        # Wait for reset to complete
        await RisingEdge(dut.clk)
        
        # Assign inputs (only first 3 positions used for cases 1-2, 5 for case 3)
        # For simplicity, we'll only test cases with n<=4
        n = len(test['f'])
        
        # Map values to signals
        for idx in range(4):
            if idx < n:
                # Get signal names
                f_sig = getattr(dut, f'f{idx}')
                p_sig = getattr(dut, f'p{idx}')
                m_sig = getattr(dut, f'm{idx}')
                s_sig = getattr(dut, f's{idx}')
                
                f_sig.value = clamp_to_width(test['f'][idx], F_WIDTH)
                p_sig.value = clamp_to_width(test['p'][idx], DATA_WIDTH)
                m_sig.value = clamp_to_width(test['m'][idx], DATA_WIDTH)
                s_sig.value = clamp_to_width(test['s'][idx], STOCK_WIDTH)
            else:
                # Set unused positions to safe values
                f_sig = getattr(dut, f'f{idx}')
                p_sig = getattr(dut, f'p{idx}')
                m_sig = getattr(dut, f'm{idx}')
                s_sig = getattr(dut, f's{idx}')
                
                f_sig.value = idx + 1  # Self-loop
                p_sig.value = 0
                m_sig.value = 0
                s_sig.value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 100:
                raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.profit.value):
            raise TestFailure(f"Test {i+1}: Profit output is undefined")
        
        result = int(dut.profit.value)
        expected = test['expected']
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: profit = {result}")
        
        # Wait for done to go low
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test 1: Zero profit (equal cost and market price)
    dut._log.info("Testing zero profit case...")
    for idx in range(4):
        getattr(dut, f'f{idx}').value = idx + 1
        getattr(dut, f'p{idx}').value = 10
        getattr(dut, f'm{idx}').value = 10
        getattr(dut, f's{idx}').value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 100:
            raise TestFailure("Timeout in zero profit test")
    
    result = int(dut.profit.value)
    if result != 0:
        raise TestFailure(f"Zero profit test failed: got {result}")
    dut._log.info(f"  PASS: profit = {result}")
    
    await RisingEdge(dut.clk)
    
    # Test 2: Negative profit (should still compute, but we might not select it)
    dut._log.info("Testing negative profit case...")
    # Position 0: f=1, p=100, m=1, s=1 => profit = -99
    # Position 1: f=2, p=1, m=1, s=0 (no stock)
    # Position 2: f=3, p=1, m=1, s=0
    # Position 3: f=4, p=1, m=1, s=0
    # Best is to do nothing (profit 0)
    
    getattr(dut, f'f0').value = 1
    getattr(dut, f'p0').value = 100
    getattr(dut, f'm0').value = 1
    getattr(dut, f's0').value = 1
    
    for idx in range(1, 4):
        getattr(dut, f'f{idx}').value = idx + 1
        getattr(dut, f'p{idx}').value = 1
        getattr(dut, f'm{idx}').value = 1
        getattr(dut, f's{idx}').value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 100:
            raise TestFailure("Timeout in negative profit test")
    
    result = int(dut.profit.value)
    # Should be 0 (no transactions)
    if result != 0:
        raise TestFailure(f"Negative profit test failed: expected 0, got {result}")
    dut._log.info(f"  PASS: profit = {result}")
    
    await RisingEdge(dut.clk)
    
    dut._log.info("Edge case tests passed!")