import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def smart_sort_test(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1

    async def run_sort(test_array, num_elems, expected):
        # Load inputs
        for i in range(8):
            dut.array_in[i].value = test_array[i] if i < num_elems else 0
        dut.num_elements.value = num_elems
        
        # Start sort
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            
        # Check outputs
        result = [int(dut.sorted_array[i].value) for i in range(num_elems)]
        assert result == expected, f"{test_array[:num_elems]} => {result}, expected {expected}"

    # Test cases (converted)
    await reset()
    test_cases = [
        ([5], 1, [5]),
        ([2,4,3,0,1,5], 6, [0,1,2,3,4,5]),
        ([2,4,3,0,1,5,6], 7, [6,5,4,3,2,1,0]),
        ([2,1], 2, [1,2]),
        ([15,42,87,32,11,0], 6, [0,11,15,32,42,87]),
        ([21,14,23,11], 4, [23,21,14,11])
    ]
    
    passed = 0
    total = len(test_cases)
    
    for arr, n, exp in test_cases:
        try:
            await run_sort(arr + [0]*(8-len(arr)), n, exp)
            passed += 1
            dut._log.info(f"Passed: {arr[:n]} => {exp}")
        except AssertionError as e:
            dut._log.error(str(e))
    
    dut._log.info(f"Test summary: {passed}/{total} cases passed")