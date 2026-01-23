import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_sort_array(dut):
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset initialization
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_length.value = 0
    for i in range(8):
        dut.array_in[i].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # (length, input_array, expected_output, description)
        (0, [], [], "Empty array"),
        (1, [5], [5], "Single element"),
        (6, [2, 4, 3, 0, 1, 5], [0, 1, 2, 3, 4, 5], "Sum Odd (2+5=7) -> Ascending"),
        (7, [2, 4, 3, 0, 1, 5, 6], [6, 5, 4, 3, 2, 1, 0], "Sum Even (2+6=8) -> Descending"),
        (2, [2, 1], [1, 2], "Sum Odd (2+1=3) -> Ascending"),
        (6, [15, 42, 87, 32, 11, 0], [0, 11, 15, 32, 42, 87], "Sum Odd (15+0=15) -> Ascending"),
        (4, [21, 14, 23, 11], [23, 21, 14, 11], "Sum Even (21+11=32) -> Descending")
    ]

    passed = 0
    total = len(test_cases)

    for length, inp, expected, desc in test_cases:
        # Load inputs
        dut.array_length.value = length
        for i in range(8):
            if i < length:
                dut.array_in[i].value = inp[i]
            else:
                dut.array_in[i].value = 0
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 200:
                raise TestFailure(f"Timeout for case: {desc}")
        
        # Check results
        result = []
        for i in range(length):
            result.append(int(dut.array_out[i].value))
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {desc}")
        else:
            dut._log.error(f"FAIL: {desc}")
            dut._log.error(f"  Expected: {expected}")
            dut._log.error(f"  Got:      {result}")
            
        await RisingEdge(dut.clk)

    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, "Some tests failed"
