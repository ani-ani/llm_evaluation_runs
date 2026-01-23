import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def digit_sum(n):
    """Calculate sum of decimal digits of absolute value"""
    n = abs(n)
    s = 0
    while n > 0:
        s += n % 10
        n //= 10
    return s

def order_by_points_py(nums):
    """Python reference implementation"""
    if not nums:
        return []
    # Sort by digit sum, then by original index
    indexed = [(i, x) for i, x in enumerate(nums)]
    indexed.sort(key=lambda item: (digit_sum(item[1]), item[0]))
    return [x for _, x in indexed]

@cocotb.test()
async def test_order_by_points(dut):
    """Test order_by_points module"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.count.value = 0
    for i in range(8):
        dut.nums[i].value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        [1, 11, -1, -11, -12],
        [1234, 423, 463, 145, 2, 423, 423, 53],
        [],
        [1, -11, -32, 43, 54, -98, 2, -3],
        [1, 2, 3, 4, 5, 6, 7, 8],
        [0, 6, 6, -76, -21, 23, 4],
        [-1, -100, 10, 200, -5],
        [45, 36, 27, 18, 9, 0]
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, test_input in enumerate(test_cases):
        dut._log.info(f"Test {idx+1}: Input = {test_input}")
        
        # Setup input
        dut.count.value = len(test_input)
        for i in range(8):
            if i < len(test_input):
                dut.nums[i].value = test_input[i]
            else:
                dut.nums[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 200
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            dut._log.error("Timeout waiting for done")
            continue
        
        # Read result
        result = []
        count = int(dut.done_count.value)
        for i in range(count):
            result.append(int(dut.result[i].value))
        
        # Expected
        expected = order_by_points_py(test_input)
        
        dut._log.info(f"Expected: {expected}")
        dut._log.info(f"Got:      {result}")
        
        # Verify
        if result == expected and count == len(expected):
            passed += 1
            dut._log.info("PASS")
        else:
            dut._log.error("FAIL")
    
    dut._log.info(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
