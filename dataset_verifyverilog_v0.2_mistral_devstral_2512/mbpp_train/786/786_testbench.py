import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_right_insertion(dut):
    """Test right insertion point finder"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.value.value = 0
    for i in range(8):
        dut.sorted_data[i].value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([1, 2, 4, 5], 6, 4),
        ([1, 2, 4, 5], 3, 2),
        ([1, 2, 4, 5], 7, 4),
        ([1, 1, 2, 2], 1, 2),
        ([10, 20, 30, 40], 5, 0),
    ]
    
    passed = 0
    for data, val, expected in test_cases:
        # Load array
        for i in range(8):
            if i < len(data):
                dut.sorted_data[i].value = data[i]
            else:
                dut.sorted_data[i].value = 0
        dut.value.value = val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        result = int(dut.position.value)
        if result == expected:
            passed += 1
            print(f"PASS: {data} + {val} -> {result}")
        else:
            print(f"FAIL: {data} + {val} -> {result}, expected {expected}")
    
    print(f"
{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), f"Only {passed} of {len(test_cases)} tests passed"