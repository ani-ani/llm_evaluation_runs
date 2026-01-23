import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_heap_sort(dut):
    """Test heap sort module with various input arrays"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_elements.value = 0
    for i in range(16):
        dut.data_in[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([1, 3, 5, 7, 9, 2, 4, 6, 8, 0], 10),
        ([25, 35, 22, 85, 14, 65, 75, 25, 58], 9),
        ([7, 1, 9, 5], 4),
        ([100, 50, 200, 75, 150], 5),
        ([1, 2, 3, 4, 5], 5),
        ([5, 4, 3, 2, 1], 5),
        ([42], 1),
        ([50, 25], 2),
        ([10, 20, 30, 40, 50, 60, 70, 80], 8),
        ([80, 70, 60, 50, 40, 30, 20, 10], 8),
        ([0, 0, 0, 0], 4),
        ([65535, 32768, 1, 0], 4),
        ([100, 200, 50, 150, 300, 25], 6),
        ([9999, 8888, 7777, 6666, 5555, 4444, 3333, 2222, 1111, 0], 10),
        ([5, 3, 8, 1, 9, 2, 7, 4, 6, 0, 10, 12, 11, 13, 15, 14], 16)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (input_array, num_elems) in enumerate(test_cases):
        print(f"
Test {idx + 1}: Input = {input_array}")
        
        # Load input array
        dut.num_elements.value = num_elems
        for i in range(16):
            if i < num_elems:
                dut.data_in[i].value = input_array[i]
            else:
                dut.data_in[i].value = 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 500:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 500:
            print(f"  FAILED: Timeout waiting for done signal")
            continue
        
        # Read output
        output = []
        for i in range(num_elems):
            output.append(int(dut.data_out[i].value))
        
        expected = sorted(input_array)
        
        if output == expected:
            print(f"  Output = {output}")
            print(f"  PASSED")
            passed += 1
        else:
            print(f"  Output = {output}")
            print(f"  Expected = {expected}")
            print(f"  FAILED")
        
        await RisingEdge(dut.clk)
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} out of {total} tests passed"
