import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_heap_sort(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (adapted to 8 elements with 0xFF padding)
    test_cases = [
        ([7, 1, 9, 5, 0xFF, 0xFF, 0xFF, 0xFF], [1, 5, 7, 9, 0xFF, 0xFF, 0xFF, 0xFF]), 
        ([3, 2, 1, 6, 5, 4, 0xFF, 0xFF], [1, 2, 3, 4, 5, 6, 0xFF, 0xFF]),
        ([8,7,6,5,4,3,2,1], [1,2,3,4,5,6,7,8])
    ]

    passed = 0
    for input_arr, expected in test_cases:
        # Apply inputs
        for i in range(8):
            dut.data_in[i].value = input_arr[i]
        
        # Start sorting
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 40 cycles)
        for _ in range(40):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        else:
            assert False, "Timeout waiting for done signal"

        # Verify outputs
        result = [dut.data_out[i].value.integer for i in range(8)]
        if result == expected:
            dut._log.info(f"PASS: {input_arr} => {result}")
            passed += 1
        else:
            dut._log.error(f"FAIL: Input={input_arr}
  Expected={expected}
  Received={result}")

    # Final summary
    total = len(test_cases)
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    assert passed == total