import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_dragon_sequence_solver(dut):
    """Test the dragon sequence solver with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.sequence_length.value = 0
    dut.sequence_data.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (sequence_as_list, expected_output)
    test_cases = [
        # Example 1: [1, 2, 1, 2] -> reverse [2,3] -> [1, 1, 2, 2] -> length 4
        ([1, 2, 1, 2], 4),
        # Example 2: [1, 1, 2, 2, 2, 1, 1, 2, 2, 1] -> length 9
        ([1, 1, 2, 2, 2, 1, 1, 2, 2, 1], 9),
        # Edge case: Single element [2] -> length 1
        ([2], 1),
        # Edge case: [1, 2] -> length 2
        ([1, 2], 2),
        # Edge case: [2, 1] -> reverse [1,2] -> [1, 2] -> length 2
        ([2, 1], 2),
        # Complex: [2, 1, 2] -> length 3 (reverse [1,2] -> [1, 2, 2] or similar)
        ([2, 1, 2], 3),
        # Complex: [1, 2, 1] -> length 3
        ([1, 2, 1], 3),
        # All 1s: [1, 1, 1] -> length 3
        ([1, 1, 1], 3),
        # All 2s: [2, 2, 2] -> length 3
        ([2, 2, 2], 3),
        # Mixed long: [2, 2, 1, 1, 2, 2] -> can get 1,1,2,2 (length 4) or better
        ([2, 2, 1, 1, 2, 2], 6),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (seq_list, expected) in enumerate(test_cases):
        # Pack sequence into bits
        # Format: value 1 -> 01 (binary), value 2 -> 10 (binary)
        packed_data = 0
        for i, val in enumerate(seq_list):
            if val == 1:
                packed_data |= 0b01 << (2 * i)
            elif val == 2:
                packed_data |= 0b10 << (2 * i)
        
        # Inputs
        dut.sequence_length.value = len(seq_list)
        dut.sequence_data.value = packed_data
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 50  # Max cycles to wait
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test case {idx+1} timed out")
        
        # Read result
        result = int(dut.max_length.value)
        
        # Check
        if result == expected:
            passed += 1
            print(f"Test {idx+1} PASSED: Sequence {seq_list} -> Result {result} (Expected {expected})")
        else:
            print(f"Test {idx+1} FAILED: Sequence {seq_list} -> Result {result} (Expected {expected})")
            raise TestFailure(f"Mismatch in test case {idx+1}")
        
        # Small delay between tests
        await Timer(10, units='ns')
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
