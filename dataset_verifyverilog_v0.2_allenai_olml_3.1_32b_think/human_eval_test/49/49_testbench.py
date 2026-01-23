import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_modp(dut):
    """Test modp module with various n and p values"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.p.value = 0
    await Timer(30, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, p, expected_result)
    test_cases = [
        (3, 5, 3),
        (1101 % 256, 101, 2),  # scaled n to fit 8-bit
        (0, 101, 1),
        (3, 11, 8),
        (100, 101, 1),
        (30 % 256, 5, 4),
        (31 % 256, 5, 3),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, p_val, expected in test_cases:
        # Set inputs
        dut.n.value = n_val
        dut.p.value = p_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 20
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"TIMEOUT: n={n_val}, p={p_val}")
            continue
        
        # Read result
        result = int(dut.result.value)
        
        # Verify
        if result == expected:
            print(f"PASS: 2^{n_val} mod {p_val} = {result} (expected {expected})")
            passed += 1
        else:
            print(f"FAIL: 2^{n_val} mod {p_val} = {result} (expected {expected})")
        
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
