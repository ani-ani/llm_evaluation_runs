import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_maximal_factoring(dut):
    """Test maximal factoring computation with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.char_in.value = 0
    dut.str_len.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ("PRATTATTATTIC", 6),
        ("GGGGGGGGG", 1),
        ("PRIME", 5),
        ("BABBABABBABBA", 6),
        ("ARPARPARPARPAR", 5),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_str, expected in test_cases:
        # Fill 16-character buffer
        str_16 = test_str.ljust(16, '\0')
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Load characters
        for i in range(16):
            dut.valid_in.value = 1
            dut.char_in.value = ord(str_16[i]) if i < len(test_str) else 0
            await RisingEdge(dut.clk)
        
        dut.valid_in.value = 0
        dut.str_len.value = len(test_str)
        
        # Wait for computation (allow up to 5000 cycles)
        for _ in range(5000):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
            dut._log.info(f"Test '{test_str}': PASSED (expected={expected}, got={actual})")
        else:
            dut._log.error(f"Test '{test_str}': FAILED (expected={expected}, got={actual})")
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
