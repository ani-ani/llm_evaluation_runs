import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def sort_and_select(arr, k):
    """Python reference: sort ascending, take last k, return in ascending order"""
    sorted_arr = sorted(arr)
    return sorted_arr[-k:] if k > 0 else []

@cocotb.test()
async def test_maximum_k(dut):
    """Test maximum_k module with various inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    dut.n.value = 0
    for i in range(7):
        dut.arr[i].value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from original problem (scaled down if needed)
    test_cases = [
        # (arr, k, expected_result)
        ([-3, -4, 5], 3, [-4, -3, 5]),
        ([4, -4, 4], 2, [4, 4]),
        ([-3, 2, 1, 2, -1, -2, 1], 1, [2]),
        ([123, -123, 20, 0, 1, 2, -3], 3, [2, 20, 123]),
        ([-123, 20, 0, 1, 2, -3], 4, [0, 1, 2, 20]),
        ([5, 15, 0, 3, -13, -8, 0], 7, [-13, -8, 0, 0, 3, 5, 15]),
        ([-1, 0, 2, 5, 3, -10], 2, [3, 5]),
        ([1, 0, 5, -7], 1, [5]),
        ([4, -4], 2, [-4, 4]),
        ([-10, 10], 2, [-10, 10]),
        ([1, 2, 3, -23, 243, -400, 0], 0, []),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for arr_in, k_in, expected in test_cases:
        # Setup inputs
        dut.k.value = k_in
        dut.n.value = len(arr_in)
        for i in range(7):
            if i < len(arr_in):
                # Handle signed values properly
                val = arr_in[i]
                if val < 0:
                    dut.arr[i].value = (1 << 8) + val  # 2's complement for 8 bits
                else:
                    dut.arr[i].value = val
            else:
                dut.arr[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 500
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Timeout for arr={arr_in}, k={k_in}")
        
        # Read results
        result = []
        for i in range(k_in):
            val = dut.result[i].value
            if val >= 128:  # Handle signed 8-bit
                val = val - 256
            result.append(int(val))
        
        # Verify
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: arr={arr_in}, k={k_in} -> {result}")
        else:
            dut._log.error(f"FAIL: arr={arr_in}, k={k_in}")
            dut._log.error(f"  Expected: {expected}")
            dut._log.error(f"  Got:      {result}")
        
        await RisingEdge(dut.clk)  # Gap between tests
    
    dut._log.info(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
