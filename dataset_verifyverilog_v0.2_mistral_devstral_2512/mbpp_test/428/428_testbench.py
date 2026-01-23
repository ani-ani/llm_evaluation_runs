import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_shell_sort_8(dut):
    """Test Shell Sort module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.data_in[i].value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(10, units='ns')
    
    # Test cases
    test_cases = [
        ([12, 23, 4, 5, 3, 2, 12, 81], [2, 3, 4, 5, 12, 12, 23, 81]),
        ([24, 22, 39, 34, 87, 73, 68, 0], [0, 22, 24, 34, 39, 68, 73, 87]),
        ([32, 30, 16, 96, 82, 83, 74, 100], [16, 30, 32, 74, 82, 83, 96, 100]),
        ([255, 0, 128, 64, 192, 32, 160, 96], [0, 16, 32, 64, 96, 128, 192, 255]),
        ([5, 5, 5, 5, 5, 5, 5, 5], [5, 5, 5, 5, 5, 5, 5, 5])
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (input_arr, expected) in enumerate(test_cases):
        print(f"
Test {idx+1}: Input={input_arr}")
        
        # Load input
        for i in range(8):
            dut.data_in[i].value = input_arr[i]
        await Timer(1, units='ns')
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 12 cycles + safety)
        max_cycles = 20
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Read result
        result = [int(dut.result[i].value) for i in range(8)]
        print(f"  Expected: {expected}")
        print(f"  Got:      {result}")
        
        # Verify
        assert result == expected, f"Mismatch: expected {expected}, got {result}"
        print(f"  ✓ Test {idx+1} passed")
        passed += 1
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
