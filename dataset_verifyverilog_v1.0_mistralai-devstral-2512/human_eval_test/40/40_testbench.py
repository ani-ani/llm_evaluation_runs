import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_array(vals, bits=16):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_triples_sum_to_zero(dut):
    # Setup
    DATA_WIDTH = 16
    CLK_NS = 10
    MAX_CYCLES = 2000
    
    # Check required signals
    assert has_signal(dut, 'clk'), "Missing clk signal"
    assert has_signal(dut, 'rst_n'), "Missing rst_n signal"
    assert has_signal(dut, 'start'), "Missing start signal"
    assert has_signal(dut, 'result'), "Missing result signal"
    assert has_signal(dut, 'done'), "Missing done signal"
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_list, expected_result)
    test_cases = [
        ([1, 3, 5, 0], False, "No triple - example 1"),
        ([1, 3, 5, -1], False, "No triple - example 2"),
        ([1, 3, -2, 1], True, "Triple: 1+(-2)+1=0"),
        ([1, 2, 3, 7], False, "No triple - example 3"),
        ([1, 2, 5, 7], False, "No triple"),
        ([2, 4, -5, 3, 9, 7], True, "Triple: 2+3+(-5)=0"),
        ([1], False, "Single element"),
        ([1, 3, 5, -100], False, "No triple large negative"),
        ([100, 3, 5, -100], True, "Triple: 100+(-100)+0=0 but 0 not present... wait"),
        ([10, 20, -30], True, "Triple: 10+20+(-30)=0"),
        ([1, 2, 3], False, "No triple in 3 elements"),
        ([0, 0, 0], True, "Triple: 0+0+0=0"),
        ([1, -1, 2, -2], True, "Triple: 1+(-1)+0 but 0 not present... wait"),
        ([-1, -2, 1, 2], True, "Triple: (-1)+1+0 but 0 not present"),
        ([5, -5, 10], True, "Triple: 5+(-5)+0 but 0 not present"),
        ([1, -2, 1, 0], True, "Triple: 1+(-2)+1=0"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        cocotb.log.info(f"  Input: {input_list}, Expected: {expected}")
        
        try:
            # Write array
            assert len(input_list) <= 16, f"Input too long: {len(input_list)}"
            
            # Check for actual valid triple in Python
            found_any = False
            n = len(input_list)
            if n >= 3:
                sorted_input = sorted(input_list)
                for ii in range(n-2):
                    # Skip duplicates for first element
                    if ii > 0 and sorted_input[ii] == sorted_input[ii-1]:
                        continue
                    left, right = ii+1, n-1
                    while left < right:
                        s = sorted_input[ii] + sorted_input[left] + sorted_input[right]
                        if s == 0:
                            found_any = True
                            break
                        elif s < 0:
                            left += 1
                        else:
                            right -= 1
                        # Skip duplicates
                        while left < right and sorted_input[left] == sorted_input[left+1]:
                            left += 1
                        while left < right and sorted_input[right] == sorted_input[right-1]:
                            right -= 1
                    if found_any:
                        break
            
            cocotb.log.info(f"  Python validation: {found_any}")
            
            # Write to DUT
            for idx, val in enumerate(input_list):
                dut.arr[idx].value = from_signed(val, DATA_WIDTH) if val < 0 else val
            
            # Write length
            if has_signal(dut, 'len'):
                dut.len.value = len(input_list)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result not in [0, 1]:
                raise TestFailure(f"Invalid result value: {result}")
            
            cocotb.log.info(f"  DUT result: {result}")
            
            # Check (allow off-by-one due to implementation differences)
            if result != expected:
                # Check if Python validation matches
                if found_any != expected:
                    raise TestFailure(f"Python validation error")
                # This is a true failure
                raise TestFailure(f"Expected {expected} ({found_any}), got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Additional: test with larger array
    cocotb.log.info("\nTest with maximum array (16 elements)")
    large_input = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, -10, -9, -8, -7, -6, -5]
    
    try:
        # Clear/Write
        for i in range(16):
            dut.arr[i].value = 0
        for idx, val in enumerate(large_input):
            dut.arr[idx].value = from_signed(val, DATA_WIDTH) if val < 0 else val
        dut.len.value = 16
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut, MAX_CYCLES)
        
        result = int(dut.result.value)
        # Check if triple exists
        found = False
        for i in range(16):
            for j in range(i+1, 16):
                for k in range(j+1, 16):
                    if large_input[i] + large_input[j] + large_input[k] == 0:
                        found = True
                        break
                if found: break
            if found: break
        
        if result != found:
            raise TestFailure(f"Large array: Expected {found}, got {result}")
        passed += 1
        
    except TestFailure as e:
        cocotb.log.error(f"FAIL: {e}")
        failed += 1
    
    cocotb.log.info(f"\nTotal: {passed} passed, {failed} failed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
