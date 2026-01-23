import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(2):
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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_modulo_product(dut):
    """Test the modulo product computation."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (array_values, mod_val, expected_result, description)
    test_cases = [
        ([100, 10, 5, 25, 35, 14], 11, 9, "Test 1: product mod 11"),
        ([1, 1, 1], 1, 0, "Test 2: mod 1 (always 0)"),
        ([1, 2, 1], 2, 0, "Test 3: mod 2"),
        ([2, 3, 4], 5, 4, "Test 4: 2*3*4 mod 5 = 24 mod 5 = 4"),
        ([255], 16, 15, "Test 5: 255 mod 16 = 15"),
        ([1, 1, 1, 1, 1, 1, 1, 1], 100, 1, "Test 6: eight ones mod 100"),
        ([12, 34, 56, 78], 20, 8, "Test 7: complex multiplication mod 20"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (array_vals, mod_val, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Array: {array_vals}, Mod: {mod_val}, Expected: {expected}")
        
        try:
            # Write array elements individually
            for idx in range(8):
                if idx < len(array_vals):
                    val = clamp_to_width(array_vals[idx], DATA_WIDTH)
                else:
                    val = 0
                
                # Assign to individual ports
                port_name = f"arr_{idx}"
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = val
                else:
                    raise TestFailure(f"Port {port_name} not found")
            
            # Write length and modulo
            dut.len.value = clamp_to_width(len(array_vals), 4)
            dut.mod_val.value = clamp_to_width(mod_val, DATA_WIDTH)
            
            # Wait for clock edge to stabilize inputs
            await RisingEdge(dut.clk)
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
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