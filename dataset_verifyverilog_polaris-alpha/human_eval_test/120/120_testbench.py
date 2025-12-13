import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

@cocotb.test()
async def test_top_k(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([-3, -4, 5], 3, [-4, -3, 5]),
        ([4, -4, 4], 2, [4, 4]),
        ([-3, 2, 1, 2, -1, -2, 1], 1, [2]),
        ([5, 15, 0, 3, -13, -8, 0], 4, [-8, 0, 3, 5]),
        ([-10, 10], 2, [-10, 10]),
        ([1, 0, 5, -7], 1, [5]),
        ([4, -4], 2, [-4, 4])
    ]
    
    passed = 0
    for arr, k, expected in test_cases:
        # Pad input to 8 elements
        padded_arr = arr + [0]*(8 - len(arr))
        
        # Prepare inputs
        dut.start.value = 0
        dut.arr_size.value = len(arr)
        dut.k_val.value = k
        for i in range(8):
            dut.arr_data[i].value = padded_arr[i]
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Wait for completion (16 cycles)
        for _ in range(18):
            await RisingEdge(dut.clk)
        
        # Check results
        result = []
        for i in range(8):
            val = dut.result.value >> (i*12) & 0xFFF
            if val >= 2048:  # Handle negative values
                val -= 4096
            result.append(val)
        
        # Trim to expected size
        trimmed_result = result[:k]
        
        if trimmed_result == expected:
            passed += 1
            dut._log.info(f"PASS: {arr}, k={k} -> {trimmed_result}")
        else:
            dut._log.error(f"FAIL: {arr}, k={k} got {trimmed_result}, expected {expected}")
    
    # Test empty case
    dut.arr_size.value = 7
    dut.k_val.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await Timer(160, 'ns')
    if dut.result.value == 0:
        passed += 1
        dut._log.info("PASS: k=0 case")
    else:
        dut._log.error(f"FAIL: k=0 got {dut.result.value}, expected 0")
    
    dut._log.info(f"{passed}/{len(test_cases)+1} tests passed")