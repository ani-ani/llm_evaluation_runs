import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

# Prime check helper for testbench
def is_prime(n):
    if n <= 1:
        return False
    for i in range(2, int(math.isqrt(n)) + 1):
        if n % i == 0:
            return False
    return True

# Digit sum helper
def digit_sum(n):
    return sum(int(d) for d in str(n))

@cocotb.test()
async def test_prime_sum(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (pad to 32 elements with zeros)
    test_lists = [
        [0,3,2,1,3,5,7,4,5,5,5,2,181,32,4,32,3,2,32,324,4,3] + [0]*10,
        [1,0,1,8,2,4597,2,1,3,40,1,2,1,2,4,2,5,1] + [0]*14,
        [1,3,1,32,5107,34,83278,109,163,23,2323,32,30,1,9,3] + [0]*16,
        [0,724,32,71,99,32,6,0,5,91,83,0,5,6] + [0]*18,
        [0,81,12,3,1,21] + [0]*26,
        [0,8,1,2,1,7] + [0]*26,
        [8191] + [0]*31,
        [8191, 123456, 127, 7] + [0]*28
    ]
    expected = [10, 25, 13, 11, 3, 7, 19, 19]
    
    passed = 0
    total = len(test_lists)
    
    for i, (lst, exp) in enumerate(zip(test_lists, expected)):
        # Convert list to packed format
        packed = 0
        for idx, val in enumerate(lst[:32]):
            packed |= (val & 0xFFFF) << (idx * 16)
        
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load data and start
        dut.lst_packed.value = packed
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        actual = dut.digit_sum.value.integer
        if actual == exp:
            passed += 1
            dut._log.info(f"Test {i} PASSED: {actual} == {exp}")
        else:
            dut._log.error(f"Test {i} FAILED: Got {actual}, expected {exp}")
        
        # Wait a few cycles before next test
        for _ in range(3):
            await RisingEdge(dut.clk)
        
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"