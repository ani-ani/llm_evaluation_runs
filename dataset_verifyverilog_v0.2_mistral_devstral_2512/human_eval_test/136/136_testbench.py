import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

NONE_VALUE = 0x80000000

def to_signed_16(value):
    """Convert signed integer to 16-bit signed representation"""
    if value < 0:
        return (1 << 16) + value  # Two's complement
    return value

def from_output(value):
    """Convert 32-bit output to Python int, handling None"""
    if value == NONE_VALUE:
        return None
    # Sign extend from 16 to 32 bits if needed
    if value & 0x8000:  # If bit 15 is set (negative in 16-bit)
        return value | 0xFFFF0000  # Sign extend to 32 bits
    return value

@cocotb.test()
async def test_largest_smallest_integers(dut):
    """Test largest_smallest_integers module"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_list, expected_largest_neg, expected_smallest_pos)
    test_cases = [
        ([2, 4, 1, 3, 5, 7, 0, 0], None, 1),
        ([1, 3, 2, 4, 5, 6, -2, 0], -2, 1),
        ([4, 5, 3, 6, 2, 7, -7, 0], -7, 2),
        ([7, 3, 8, 4, 9, 2, 5, -9], -9, 2),
        ([0, 0, 0, 0, 0, 0, 0, 0], None, None),
        ([-1, -3, -5, -6, 0, 0, 0, 0], -1, None),
        ([-6, -4, -4, -3, 1, 0, 0, 0], -3, 1),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_list, exp_neg, exp_pos) in enumerate(test_cases):
        # Pad input to 8 elements
        padded_input = input_list + [0] * (8 - len(input_list))
        
        # Load input
        for idx, val in enumerate(padded_input):
            dut.data_in[idx].value = to_signed_16(val)
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (10 cycles total, but done goes high after 9)
        for _ in range(10):
            await RisingEdge(dut.clk)
        
        # Check done signal
        if dut.done.value != 1:
            raise TestFailure(f"Test {i}: done signal not high")
        
        # Get results
        actual_neg = from_output(int(dut.largest_negative.value))
        actual_pos = from_output(int(dut.smallest_positive.value))
        
        # Verify
        if actual_neg == exp_neg and actual_pos == exp_pos:
            passed += 1
            print(f"Test {i}: PASS - Input {input_list}")
            print(f"  Expected: ({exp_neg}, {exp_pos})")
            print(f"  Got: ({actual_neg}, {actual_pos})")
        else:
            print(f"Test {i}: FAIL - Input {input_list}")
            print(f"  Expected: ({exp_neg}, {exp_pos})")
            print(f"  Got: ({actual_neg}, {actual_pos})")
            print(f"  Raw outputs: neg=0x{int(dut.largest_negative.value):08X}, pos=0x{int(dut.smallest_positive.value):08X}")
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} out of {total} tests passed"
