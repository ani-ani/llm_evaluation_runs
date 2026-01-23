import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def str_to_bytes(s):
    """Convert string to 8-byte array, padded with zeros"""
    b = [ord(c) for c in s]
    while len(b) < 8:
        b.append(0)
    return b

def reverse_pairs_count(str_list):
    """Python reference implementation"""
    count = 0
    for i in range(len(str_list)):
        rev_i = str_list[i][::-1]
        for j in range(i + 1, len(str_list)):
            if str_list[j] == rev_i:
                count += 1
    return count

@cocotb.test()
async def test_reverse_pair_counter(dut):
    """Test reverse pair counting with fixed-width strings"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(30, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (["julia", "best", "tseb", "for", "ailuj"], 2),
        (["geeks", "best", "for", "skeeg"], 1),
        (["makes", "best", "sekam", "for", "rof"], 2)
    ]
    
    for idx, (str_list, expected) in enumerate(test_cases):
        print(f"
Test {idx + 1}: Input = {str_list}, Expected = {expected}")
        
        # Load strings into DUT
        for i, s in enumerate(str_list):
            bytes_arr = str_to_bytes(s)
            for j in range(8):
                dut.str_data[i][j].value = bytes_arr[j]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test {idx + 1}: Timeout waiting for done")
        
        # Read result
        actual = int(dut.result.value)
        print(f"Test {idx + 1}: Result = {actual}")
        
        if actual != expected:
            raise TestFailure(f"Test {idx + 1}: Expected {expected}, got {actual}")
    
    print(f"
All 3 tests passed!")