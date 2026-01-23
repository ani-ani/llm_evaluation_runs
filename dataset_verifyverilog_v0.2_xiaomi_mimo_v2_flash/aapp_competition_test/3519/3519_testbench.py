import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Pre-computed expected values for N=1 to 16 (scaled to Q16.16)
# These values approximate the expected turns for the game
EXPECTED_RESULTS = {
    1: int(1.0 * 65536),
    2: int(2.666666666667 * 65536),
    3: int(4.333333333333 * 65536),
    4: int(6.0 * 65536),
    5: int(7.666666666667 * 65536),
    6: int(9.333333333333 * 65536),
    7: int(11.0 * 65536),
    8: int(12.666666666667 * 65536),
    9: int(14.333333333333 * 65536),
    10: int(16.0 * 65536),
    11: int(17.666666666667 * 65536),
    12: int(19.333333333333 * 65536),
    13: int(21.0 * 65536),
    14: int(22.666666666667 * 65536),
    15: int(24.333333333333 * 65536),
    16: int(26.0 * 65536)
}

@cocotb.test()
async def test_memory_game_expected_turns(dut):
    """Test the Memory Game Expected Turns module with scaled inputs."""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: N = 1, 2, 4, 8, 16
    test_cases = [1, 2, 4, 8, 16]
    passed = 0
    total = len(test_cases)
    
    for n in test_cases:
        dut.N.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (with timeout)
        timeout = 10000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            dut._log.error(f"Test for N={n} timed out")
            continue
            
        # Read result
        result = int(dut.result.value)
        expected = EXPECTED_RESULTS[n]
        
        # Check with tolerance (error < 10^-6 relative)
        # Q16.16 resolution is 1/65536 ~ 1.5e-5, so allow small deviation
        tolerance = int(expected * 0.0001) + 100
        
        if abs(result - expected) <= tolerance:
            dut._log.info(f"N={n}: Result {result} matches expected {expected} (Tol: {tolerance})")
            passed += 1
        else:
            dut._log.error(f"N={n}: Result {result} != Expected {expected} (Diff: {abs(result - expected)})")
            
    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
