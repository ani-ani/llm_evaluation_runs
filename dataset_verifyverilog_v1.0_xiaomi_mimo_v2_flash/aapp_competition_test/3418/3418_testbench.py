import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N_WIDTH = 10           # Width of n input (10 bits for n up to 1023)
SUPPLY_WIDTH = 16      # Width of supply output
CLK_PERIOD_NS = 10     # Not used for combinational

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
# COMBINATIONAL MODULE HELPERS
# ============================================================================

async def wait_for_combinational(dut, timeout_ns=1000):
    """Wait for combinational logic to settle."""
    elapsed = 0
    check_interval = 10  # ns
    
    while elapsed < timeout_ns:
        await Timer(check_interval, units='ns')
        elapsed += check_interval
        
        # Check if output is valid (not X/Z)
        if is_value_defined(dut.supply.value):
            return int(dut.supply.value)
    
    raise TestFailure(f"Output not valid after {timeout_ns}ns")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_lucky_numbers(dut):
    """Test lucky numbers supply calculation."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Sequential module - start clock and reset
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (n_input, expected_supply, description)
    # n is 10-bit, so we can test up to 1023
    test_cases = [
        (1, 9, "n=1 (edge case)"),
        (2, 45, "n=2 (example)"),
        (3, 150, "n=3 (example)"),
        (4, 375, "n=4"),
        (5, 750, "n=5"),
        (6, 1200, "n=6"),
        (7, 1713, "n=7"),
        (8, 2227, "n=8 (max valid)"),
        (9, 0, "n=9 (should be 0)"),
        (10, 0, "n=10 (should be 0)"),
        (25, 0, "n=25 (should be 0)"),
        (1000, 0, "n=1000 (should be 0)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_input, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Clamp n to N_WIDTH bits
            n_val = clamp_to_width(n_input, N_WIDTH)
            
            # Set n input
            if has_signal(dut, 'n'):
                dut.n.value = n_val
            else:
                # Try individual ports (n_0, n_1, ...)
                for bit in range(N_WIDTH):
                    port_name = f'n_{bit}'
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = (n_val >> bit) & 1
                    else:
                        raise TestFailure(f"Cannot find n port: n_{bit}")
            
            if is_sequential:
                # Sequential: pulse start and wait for done
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    
                    # Wait for done
                    max_cycles = 100
                    for cycle in range(max_cycles):
                        await RisingEdge(dut.clk)
                        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                            break
                    else:
                        raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")
                else:
                    # Sequential without start/done - just wait
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)
            else:
                # Combinational - wait for propagation
                await wait_for_combinational(dut)
            
            # Read result
            if not is_value_defined(dut.supply.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.supply.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: supply = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
