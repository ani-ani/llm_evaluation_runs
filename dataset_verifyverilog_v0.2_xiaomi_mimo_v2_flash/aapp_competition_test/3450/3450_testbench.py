import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_factorial_trailing(dut):
    """Test factorial trailing digits computation for small n"""
    
    # Create clock with 10ns period
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_result)
    # 5! = 120, remove trailing zeroes -> 12, last 3 digits -> 12 (0x012)
    # 14! = 87178291200, remove trailing zeroes -> 871782912, last 3 digits -> 912 (0x912)
    # 1! = 1, remove trailing zeroes -> 1, last 3 digits -> 1 (0x001)
    # 10! = 3628800, remove trailing zeroes -> 36288, last 3 digits -> 688 (0x688)
    # 15! = 1307674368000, remove trailing zeroes -> 1307674368, last 3 digits -> 368 (0x368)
    
    test_cases = [
        (5, 0x012),    # 12
        (14, 0x912),   # 912
        (1, 0x001),    # 1
        (10, 0x688),   # 688
        (15, 0x368),   # 368
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Start computation
        dut.n.value = n
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (timeout after 200 cycles)
        timeout = 0
        while not dut.done.value and timeout < 200:
            await RisingEdge(dut.clk)
            timeout += 1
        
        # Check result
        actual = int(dut.result.value)
        print(f"n={n}: expected={expected} (0x{expected:03X}), actual={actual} (0x{actual:03X})")
        
        assert actual == expected, f"Test failed for n={n}: expected {expected}, got {actual}"
        passed += 1
        
        # Small delay between tests
        await Timer(50, units='ns')
        await RisingEdge(dut.clk)
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
