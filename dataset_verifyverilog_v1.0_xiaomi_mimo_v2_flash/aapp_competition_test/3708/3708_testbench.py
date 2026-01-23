import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Reset sequence
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'setup_mode'):
        dut.setup_mode.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Helper to convert result
async def get_result(dut):
    raw = int(dut.result.value)
    return raw if raw != 0xFF else -1

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_time_path(dut):
    """Test the min_time_path module"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, volcanoes, expected)
    # Volcanoes are 1-indexed, will convert to 0-indexed
    test_cases = [
        (4, [(1,3), (1,4)], 6),      # Example 1
        (7, [(1,6),(2,6),(3,5),(3,6),(4,3),(5,1),(5,2),(5,3)], 12),  # Example 2
        (2, [(1,2),(2,1)], -1),      # Example 3
        (3, [(1,2),(2,2),(2,1)], -1),  # Trapped
        (3, [(1,2)], 4),             # Path exists
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, volcanoes, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, volcanoes={volcanoes}, expected={expected}")
        
        try:
            # Set grid size
            dut.n.value = n_val
            
            # Setup volcanoes
            dut.setup_mode.value = 1
            for x, y in volcanoes:
                dut.volcano_valid.value = 1
                dut.volcano_x.value = x-1  # Convert to 0-indexed
                dut.volcano_y.value = y-1
                await RisingEdge(dut.clk)
            
            dut.volcano_valid.value = 0
            dut.setup_mode.value = 0
            await RisingEdge(dut.clk)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            timeout = 256  # Max cycles for 16x16 grid
            for _ in range(timeout):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f"Timeout waiting for done")
            
            # Get result
            result = await get_result(dut)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result={result}")
            passed += 1
            
            # Reset for next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\nResults: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")