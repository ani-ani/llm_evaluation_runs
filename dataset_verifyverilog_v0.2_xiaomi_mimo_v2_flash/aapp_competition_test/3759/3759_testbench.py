import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import math

@cocotb.test()
async def test_chubby_yang(dut):
    """Test Chubby Yang logic for various n values."""
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: (n, expected_output)
    # We adapt the large test cases to fit the smaller logic or limit the test to small values
    # as per the 'aggressive scaling' guidance. However, the module accepts 32-bit.
    # To demonstrate functionality, we test the small cases and a few medium ones.
    # The logic is: res = (n * 92682) >> 14
    # Verify this math in Python.
    
    test_cases = [
        (0, 1),
        (1, 4),
        (2, 8),
        (3, 16),
        (4, 20),
        (5, 28),
        (6, 32),
        (10, 56),
        (17, 96),
        (39999999, 226274164) # Large case if logic supports it
    ]

    passed = 0
    total = len(test_cases)

    for n_val, expected in test_cases:
        # Drive inputs
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 10
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            raise TestFailure(f"Timeout waiting for done. n={n_val}")
        
        # Check result
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Mismatch for n={n_val}: expected {expected}, got {actual}")
        
        passed += 1
        await RisingEdge(dut.clk) # Allow state to return to IDLE

    dut._log.info(f"{passed}/{total} tests passed")