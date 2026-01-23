import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_chessmen(dut):
    """Test max_chessmen module with various small inputs"""
    
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, m, expected_result)
    test_cases = [
        (2, 2, 0),
        (3, 3, 8),
        (1, 4, 2),
        (1, 6, 6),
        (7, 1, 6),
        (7, 2, 12),
        (2, 3, 4),
        (2, 5, 10),
        (4, 3, 12),
        (5, 5, 24),
        (1, 1, 0),
        (2, 1, 0),
        (3, 1, 0),
        (1, 8, 6),
        (9, 1, 6),
        (1, 10, 8),
        (2, 4, 8),
        (6, 2, 12),
        (2, 7, 12),
        (2, 8, 16),
        (2, 9, 18),
        (2, 11, 22),
        (3, 5, 14),
        (3, 6, 18),
        (3, 7, 20),
        (3, 2, 4),
        (4, 2, 8),
        (4, 4, 16),
        (5, 3, 14),
        (6, 6, 36),
        (8, 8, 64),
    ]
    
    passed = 0
    failed = 0
    
    for n, m, expected in test_cases:
        # Load inputs
        dut.n.value = n
        dut.m.value = m
        
        # Pulse start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (should take 2 cycles from start assertion)
        # Start was high on rising edge 1, so done should be high on rising edge 3
        # We wait until done is high
        timeout = 10
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Timeout waiting for done for inputs n={n}, m={m}")
        
        # Check result
        actual = int(dut.result.value)
        
        if actual == expected:
            passed += 1
        else:
            failed += 1
            dut._log.error(f"Test failed for n={n}, m={m}: expected {expected}, got {actual}")
            raise TestFailure(f"Mismatch for n={n}, m={m}: expected {expected}, got {actual}")
        
        # Wait for next cycle
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{len(test_cases)} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
