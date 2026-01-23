import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def str_to_bits(s):
    # Pack string into 256-bit integer (32 chars * 8 bits)
    # '(': 0x28, ')': 0x29, '#': 0x23
    val = 0
    for i, c in enumerate(s):
        if c == '(':
            code = 0x28
        elif c == ')':
            code = 0x29
        elif c == '#':
            code = 0x23
        else:
            code = 0
        val |= code << (8 * i)
    return val

def solve_py(s):
    sharp_indices = [i for i, c in enumerate(s) if c == '#']
    if not sharp_indices:
        return None # No # in this problem
    
    count_l = s.count('(')
    count_r = s.count(')')
    count_h = len(sharp_indices)
    
    diff = count_l - count_r - count_h
    
    # Assign 1 to all except last, last gets diff + 1
    # But wait, if diff < 0, then last gets <= 0, which is invalid.
    if diff < 0:
        return None
        
    # Check if it works
    balance = 0
    current_h = 0
    for c in s:
        if c == '(':
            balance += 1
        elif c == ')':
            balance -= 1
        elif c == '#':
            if current_h == count_h - 1:
                val = diff + 1
            else:
                val = 1
            balance -= val
            current_h += 1
        if balance < 0:
            return None
    
    if balance != 0:
        return None
        
    # Generate output list
    res = []
    for i in range(count_h):
        if i == count_h - 1:
            res.append(diff + 1)
        else:
            res.append(1)
    return res

@cocotb.test()
async def test_treasure_map(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_len.value = 0
    dut.str_data.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_str, expected_output_list or None for error)
    test_cases = [
        ("(((#)((#)", [1, 2]),
        ("()((#((#(#()", [1, 1, 3]),
        ("#", None),
        ("(#)", None),
        ("(((((#(#(#(#()", [1, 1, 1, 1, 5]),
        ("#))))", None),
        ("((#(()#(##", [1, 1, 1, 1]),
        ("##((((((()", None),
        ("(((((((((((((((((((###################", None), # Too many # for our 5 limit
    ]
    
    passed = 0
    total = 0
    
    for s, expected in test_cases:
        if len([c for c in s if c == '#']) > 5:
            # Skip test cases that exceed our hardware limit
            print(f"Skipping {s} (too many #)")
            continue
            
        print(f"Testing input: {s}")
        total += 1
        
        # Setup inputs
        dut.str_len.value = len(s)
        dut.str_data.value = str_to_bits(s)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (valid high)
        max_cycles = 100
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if dut.valid.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for input {s}")
            
        # Check results
        if expected is None:
            if dut.error.value != 1:
                raise TestFailure(f"Expected error for input '{s}', but got valid={dut.valid.value}, error={dut.error.value}")
            print(f"  PASSED: Correctly detected error")
            passed += 1
        else:
            if dut.error.value == 1:
                raise TestFailure(f"Expected valid result for input '{s}', but got error=1")
            
            # Extract results from packed output
            results = []
            num_sharps = int(dut.sharp_count.value)
            packed = int(dut.result_packed.value)
            
            for i in range(num_sharps):
                val = (packed >> (6 * i)) & 0x3F
                results.append(val)
                
            if results != expected:
                raise TestFailure(f"Mismatch for input '{s}': Expected {expected}, Got {results}")
            
            print(f"  PASSED: Results {results}")
            passed += 1
            
        await RisingEdge(dut.clk)
        
    print(f"
SUMMARY: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Test suite failed: {passed}/{total}")
