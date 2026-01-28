import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_arpa_land(dut):
    """Test the Arpa's Land module"""
    
    # Configuration
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, crush_1to8, expected_output)
    test_cases = [
        (4, [2, 3, 1, 4], 3),      # Example 1
        (4, [4, 4, 4, 4], -1),     # Example 2: not permutation
        (4, [2, 1, 4, 3], 1),      # Example 3
        (2, [2, 1], 1),            # Simple 2-cycle
        (3, [2, 3, 1], 3),         # 3-cycle
        (6, [2, 3, 1, 5, 6, 4], 3), # Mixed cycles
        (1, [1], 1),               # Self-loop
        (8, [2, 3, 4, 5, 6, 7, 8, 1], 4), # 8-cycle -> adjusted 4
    ]
    
    passed = 0
    failed = 0
    
    for n, crush_in, expected in test_cases:
        cocotb.log.info(f"Testing n={n}, crush={crush_in}, expected={expected}")
        
        # Convert to 0-indexed and pad to 8 elements
        crush_0idx = [x-1 for x in crush_in]
        while len(crush_0idx) < 8:
            crush_0idx.append(0)  # Pad with zeros
        
        # Set inputs
        dut.n.value = n
        
        # Write crush array via individual ports
        for i in range(8):
            port_name = f'crush_{i}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = crush_0idx[i]
            else:
                raise TestFailure(f"Signal {port_name} not found")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 1000
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        # Convert from two's complement if negative (10-bit)
        if result >= 512:  # MSB set
            result = result - 1024
        
        # Verify
        if result != expected:
            cocotb.log.error(f"Test failed: expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"Test passed: got {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")