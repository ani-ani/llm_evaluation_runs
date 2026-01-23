import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def to_fixed_point(value, width=8):
    # Not needed for integer counts
    return value

def sort_pair(a, b):
    return (a, b) if a < b else (b, a)

@cocotb.test()
async def test_occ_count(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in_0.value = 0
    dut.data_in_1.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: [(3, 1), (1, 3), (2, 5), (5, 2), (6, 3)]
    # Sorted/Normalized: (1,3), (1,3), (2,5), (2,5), (3,6)
    # Expected: (1,3):2, (2,5):2, (3,6):1
    N = 8
    data0 = [3, 1, 2, 5, 6, 0, 0, 0]
    data1 = [1, 3, 5, 2, 3, 0, 0, 0]
    
    dut.data_in_0.value = data0
    dut.data_in_1.value = data1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (NORMALIZE(8) + COUNT(8) + states)
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: Did not finish in time")
    
    # Read outputs
    keys = []
    counts = []
    for i in range(8): # MAX_DISTINCT is 8
        k = int(dut.out_keys[i].value)
        c = int(dut.out_counts[i].value)
        if c > 0:
            keys.append(k)
            counts.append(c)
    
    # Convert back to tuple (value is {low_byte, high_byte})
    # Wait, Verilog stores {data_in_1, data_in_0} if a >= b? 
    # Wait, in Verilog I did {data_in_0, data_in_1} if a < b else {data_in_1, data_in_0}.
    # Let's decode. {low, high} is how I wrote it: {data_in_0, data_in_1} implies high is data_in_1?
    # Actually standard notation {MSB, LSB}. If I write {A, B}, A is MSB. 
    # But I want {small, large}. Let's assume {small, large} is stored as 16-bit.
    # So if pair is (1,3), value is 0x0301? Or 0x0103? 
    # Let's check Verilog: if (a < b) pair = {a, b}. So {a, b} means a is high bits? No, {a, b} concatenates a then b.
    # Usually {a, b} means a is MSB. But for (1,3), it's {1, 3} = 0x0103. Wait, 1 is smaller, so 1 is high byte? 
    # Let's assume 8 bits. {1, 3} = 00000001_00000011? No, that's wrong. {A, B} is A in high bits, B in low bits.
    # If A=1 (01), B=3 (03), result is 0x0103.
    # If A=3 (03), B=1 (01), result is 0x0301.
    # So we need to sort in Python to match. Min byte is MSB? 
    # Let's assume (min, max) is stored as {min, max}. 
    # So (1,3) -> 0x0103 (259 decimal).
    # (2,5) -> 0x0205.
    # (3,6) -> 0x0306.
    
    expected_pairs = [(1,3), (2,5), (3,6)]
    expected_counts = [2, 2, 1]
    
    # Verify
    found_counts = {}
    for i in range(len(keys)):
        k_val = keys[i]
        c_val = counts[i]
        # Decode 16-bit value to (low, high)?
        # Wait, Verilog code: {data_in_0, data_in_1} if a < b.
        # If a=1 (01), b=3 (03). Result is 0x0103. 
        # In Python, to match this: ((val >> 8) & 0xFF, val & 0xFF)
        # (0x01, 0x03) -> (1, 3).
        # So: low_bits = k_val & 0xFF, high_bits = (k_val >> 8) & 0xFF.
        # Wait, Verilog concatenation {A, B} puts A in MSB. So {A, B} -> {A[7:0], B[7:0]}.
        # Result[15:8] = A, Result[7:0] = B.
        # If a < b, we did {a, b}. So MSB=a, LSB=b.
        # Example: a=1, b=3. Value = 0x0103.
        # Python int: 0x0103 = 259. 
        # Decoding: (259 >> 8) & 0xFF = 1. (259 & 0xFF) = 3.
        # So pair is (1, 3).
        
        byte_high = (k_val >> 8) & 0xFF
        byte_low = k_val & 0xFF
        # Wait, I defined it as {a, b} where a is first element (smaller?).
        # Let's stick to the standard: {val0, val1} -> high byte val0, low byte val1.
        # My code: if (a < b) pair = {a, b}. So high byte is a, low byte is b.
        pair = (byte_high, byte_low) 
        # But wait, if I have {a, b}, and I want (min, max), then (byte_high, byte_low) = (min, max).
        # Let's verify with a=3, b=1. a >= b. pair = {b, a}. So {1, 3}. High=1, Low=3.
        # So yes, (high, low) = (min, max).
        
        found_counts[pair] = c_val

    dut._log.info(f"Test 1 Results: {found_counts}")
    
    # Assertions
    for (p, c) in zip(expected_pairs, expected_counts):
        if p not in found_counts or found_counts[p] != c:
             raise TestFailure(f"Test 1 Mismatch: Expected {p}:{c}, Got {found_counts}")
    
    await RisingEdge(dut.clk)
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: [(4, 2), (2, 4), (3, 6), (6, 3), (7, 4)]
    # Normalized: (2,4), (2,4), (3,6), (3,6), (4,7)
    # Expected: (2,4):2, (3,6):2, (4,7):1
    data0 = [4, 2, 3, 6, 7, 0, 0, 0]
    data1 = [2, 4, 6, 3, 4, 0, 0, 0]
    
    dut.data_in_0.value = data0
    dut.data_in_1.value = data1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break

    keys = []
    counts = []
    for i in range(8):
        k = int(dut.out_keys[i].value)
        c = int(dut.out_counts[i].value)
        if c > 0:
            keys.append(k)
            counts.append(c)
    
    found_counts = {}
    for i in range(len(keys)):
        k_val = keys[i]
        c_val = counts[i]
        byte_high = (k_val >> 8) & 0xFF
        byte_low = k_val & 0xFF
        pair = (byte_high, byte_low)
        found_counts[pair] = c_val

    dut._log.info(f"Test 2 Results: {found_counts}")
    
    expected_pairs_2 = [(2,4), (3,6), (4,7)]
    expected_counts_2 = [2, 2, 1]
    
    for (p, c) in zip(expected_pairs_2, expected_counts_2):
        if p not in found_counts or found_counts[p] != c:
             raise TestFailure(f"Test 2 Mismatch: Expected {p}:{c}, Got {found_counts}")

    # Test Case 3: [(13, 2), (11, 23), (12, 25), (25, 12), (16, 23)]
    # Normalized: (2,13), (11,23), (12,25), (12,25), (16,23)
    # Expected: (2,13):1, (11,23):1, (12,25):2, (16,23):1
    data0 = [13, 11, 12, 25, 16, 0, 0, 0]
    data1 = [2, 23, 25, 12, 23, 0, 0, 0]
    
    dut.data_in_0.value = data0
    dut.data_in_1.value = data1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break

    keys = []
    counts = []
    for i in range(8):
        k = int(dut.out_keys[i].value)
        c = int(dut.out_counts[i].value)
        if c > 0:
            keys.append(k)
            counts.append(c)
    
    found_counts = {}
    for i in range(len(keys)):
        k_val = keys[i]
        c_val = counts[i]
        byte_high = (k_val >> 8) & 0xFF
        byte_low = k_val & 0xFF
        pair = (byte_high, byte_low)
        found_counts[pair] = c_val

    dut._log.info(f"Test 3 Results: {found_counts}")
    
    expected_pairs_3 = [(2,13), (11,23), (12,25), (16,23)]
    expected_counts_3 = [1, 1, 2, 1]
    
    for (p, c) in zip(expected_pairs_3, expected_counts_3):
        if p not in found_counts or found_counts[p] != c:
             raise TestFailure(f"Test 3 Mismatch: Expected {p}:{c}, Got {found_counts}")
             
    dut._log.info("All tests passed!")