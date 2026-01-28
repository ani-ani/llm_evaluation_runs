import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    # Clamp 8-bit signed: -128 to 127
    min_val = -(1 << (bits-1))
    max_val = (1 << (bits-1)) - 1
    return max(min_val, min(max_val, v))

def to_signed(val, bits):
    """Convert Python int to 2's complement representation"""
    if val < 0:
        return (1 << bits) + val
    return val

def from_signed(val, bits):
    """Convert 2's complement to Python int"""
    if val >= (1 << (bits-1)):
        return val - (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def sort_third_reference(l):
    """Reference Python implementation"""
    l = list(l)  # Make copy
    third_indices = [i for i in range(len(l)) if i % 3 == 0]
    if len(third_indices) < 2:
        return l
    
    # Extract values at third indices
    third_vals = [l[i] for i in third_indices]
    # Sort them
    third_vals.sort()
    # Put back
    for idx, val in zip(third_indices, third_vals):
        l[idx] = val
    return l

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sort_third(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_list, description)
    test_cases = [
        ([1, 2, 3], "Simple 3 elements"),
        ([5, 6, 3, 4, 8, 9, 2], "7 elements"),
        ([5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10], "11 elements with negatives"),
        ([5, 8, -12, 4, 23, 2, 3, 11, 12, -10], "10 elements"),
        ([5, 8, 3, 4, 6, 9, 2], "7 elements variant 2"),
        ([5, 6, 9, 4, 8, 3, 2], "7 elements variant 3"),
        ([5, 6, 3, 4, 8, 9, 2, 1], "8 elements"),
        ([0, 0, 0, 0, 0, 0, 0], "All zeros"),
        ([100, -100, 50, -50, 0, 200, -200], "Full range values"),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], "16 elements"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {inp}")
        
        try:
            # Calculate expected output
            expected = sort_third_reference(inp)
            
            # Pad input to 16 elements
            padded_input = inp + [0] * (ARRAY_SIZE - len(inp))
            
            # Clamp values to 8-bit signed range and convert
            clamped_input = [clamp_to_width(v, DATA_WIDTH) for v in padded_input]
            
            # Write input array to DUT (MUST be individual assignment)
            if is_seq:
                for j in range(ARRAY_SIZE):
                    attr_name = f'arr_{j}'
                    if hasattr(dut, attr_name):
                        getattr(dut, attr_name).value = to_signed(clamped_input[j], DATA_WIDTH)
                    else:
                        raise TestFailure(f"Signal {attr_name} not found")
                
                # Set length
                if hasattr(dut, 'length'):
                    dut.length.value = len(inp)
                
                # Start processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read results
                result = []
                for j in range(ARRAY_SIZE):
                    result_name = f'result_{j}'
                    if hasattr(dut, result_name):
                        val = int(getattr(dut, result_name).value)
                        # Convert 2's complement to signed
                        result.append(from_signed(val, DATA_WIDTH))
                    else:
                        raise TestFailure(f"Signal {result_name} not found")
                
                # Check only the first 'len(inp)' elements
                actual_result = result[:len(inp)]
                
            else:
                # Combinational - just wait
                for j in range(ARRAY_SIZE):
                    attr_name = f'arr_{j}'
                    if hasattr(dut, attr_name):
                        getattr(dut, attr_name).value = to_signed(clamped_input[j], DATA_WIDTH)
                    else:
                        raise TestFailure(f"Signal {attr_name} not found")
                
                if hasattr(dut, 'length'):
                    dut.length.value = len(inp)
                
                await Timer(100, units='ns')
                
                # Read results
                result = []
                for j in range(ARRAY_SIZE):
                    result_name = f'result_{j}'
                    if hasattr(dut, result_name):
                        val = int(getattr(dut, result_name).value)
                        result.append(from_signed(val, DATA_WIDTH))
                    else:
                        raise TestFailure(f"Signal {result_name} not found")
                
                actual_result = result[:len(inp)]
            
            # Verify
            if len(actual_result) != len(expected):
                raise TestFailure(f"Length mismatch: got {len(actual_result)}, expected {len(expected)}")
            
            for j, (got, exp) in enumerate(zip(actual_result, expected)):
                if got != exp:
                    raise TestFailure(f"Index {j}: got {got}, expected {exp} (full result: {actual_result})")
            
            passed += 1
            cocotb.log.info(f"  PASSED: {actual_result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        if is_seq and i < len(test_cases) - 1:
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")