import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def to_twos_complement(value, bits):
    """Convert signed integer to 2's complement representation"""
    if value < 0:
        return (1 << bits) + value
    return value

@cocotb.test()
async def test_array_partition(dut):
    """Test array partition module"""
    
    # Create clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.arr.value = [0] * 8
    dut.n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (input_array, n, expected_output)
        ([-1, 2, -3, 4, 5, 6, -7, 8], 8, [-1, -3, -7, 2, 4, 5, 6, 8]),
        ([12, -14, -26, 13, 15], 5, [-14, -26, 12, 13, 15]),
        ([10, 24, 36, -42, -39, -78, 85], 7, [-42, -39, -78, 10, 24, 36, 85]),
        ([-5, -3, -1, 1, 3, 5], 6, [-5, -3, -1, 1, 3, 5]),  # Already sorted
        ([5, 3, 1, -1, -3, -5], 6, [-1, -3, -5, 5, 3, 1]),  # Reverse
        ([0, -1, 2, -3, 4], 5, [0, -1, -3, 2, 4]),  # Contains zero
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (input_arr, n, expected) in enumerate(test_cases):
        # Prepare input (pad to 8 elements)
        padded_input = input_arr + [0] * (8 - len(input_arr))
        
        # Convert to 2's complement for Verilog
        input_twos = [to_twos_complement(x, 8) for x in padded_input]
        expected_twos = [to_twos_complement(x, 8) for x in (expected + [0] * (8 - len(expected)))]
        
        # Set inputs
        dut.arr.value = input_twos
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 100
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test {idx+1}: Timeout - done never went high")
        
        # Read result
        result = [int(dut.result.value[i]) for i in range(8)]
        
        # Convert back from 2's complement
        result_signed = []
        for r in result:
            if r >= 128:
                result_signed.append(r - 256)
            else:
                result_signed.append(r)
        
        # Extract only first n elements for comparison
        result_final = result_signed[:n]
        
        # Verify
        if result_final != expected:
            print(f"Test {idx+1} FAILED:")
            print(f"  Input: {input_arr[:n]} (n={n})")
            print(f"  Expected: {expected}")
            print(f"  Got: {result_final}")
            raise TestFailure(f"Test {idx+1} failed")
        else:
            print(f"Test {idx+1} PASSED")
            passed += 1
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
