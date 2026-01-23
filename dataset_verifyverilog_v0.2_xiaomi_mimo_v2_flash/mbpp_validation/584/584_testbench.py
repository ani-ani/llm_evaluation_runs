import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_adverb_finder(dut):
    """Test adverb finding with 16-character fixed-width strings"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Helper function to convert string to 128-bit hex
    def str_to_bits(s):
        # Pad to 16 characters, store left-to-right
        padded = s.ljust(16, '\0')
        hex_str = ''.join(f'{ord(c):02x}' for c in padded)
        return int(hex_str, 16)
    
    # Test cases
    tests = [
        ("Clearly, he has n", 0, 7, 1),  # Test 1: Clearly at 0-7
        ("Please handle the si", 11, 19, 1),  # Test 2: carefully at 11-19
        ("Complete the task q", 13, 20, 1),   # Test 3: quickly at 13-20
        ("No adverbs here", 0, 0, 0),         # Test 4: no match
        ("lytest testly test", 8, 12, 1),     # Test 5: testly at 8-12
    ]
    
    for i, (text_str, exp_start, exp_end, exp_found) in enumerate(tests):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load input
        dut.text.value = str_to_bits(text_str)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 20 cycles)
        timeout = 25
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test {i+1}: Timeout - done never asserted")
        
        # Check results
        if exp_found:
            if dut.found.value != 1:
                raise TestFailure(f"Test {i+1}: Expected found=1, got {dut.found.value}")
            actual_start = int(dut.start_pos.value)
            actual_end = int(dut.end_pos.value)
            if actual_start != exp_start or actual_end != exp_end:
                raise TestFailure(f"Test {i+1}: Expected {exp_start}-{exp_end}, got {actual_start}-{actual_end}")
        else:
            if dut.found.value != 0:
                raise TestFailure(f"Test {i+1}: Expected found=0, got {dut.found.value}")
        
        print(f"Test {i+1}: PASS - Text: '{text_str}', Result: {int(dut.start_pos.value)}-{int(dut.end_pos.value)} found={dut.found.value}")
    
    print(f"
Result: {len(tests)}/{len(tests)} tests passed")