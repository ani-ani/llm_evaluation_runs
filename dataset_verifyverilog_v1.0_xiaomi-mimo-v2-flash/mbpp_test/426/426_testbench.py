import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def to_signed(val, bits):
    if val >= (1 << (bits-1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Configuration
DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 100

def create_test_input(length):
    """Generate random input array with exactly length valid entries"""
    arr = []
    for _ in range(length):
        # Random 8-bit signed value
        val = random.randint(0, 127)
        arr.append(val)
    # Pad with zeros
    while len(arr) < MAX_LEN:
        arr.append(0)
    return arr

def filter_odd_expected(input_array, length):
    """Python reference for expected output"""
    odd_nums = []
    for i in range(length):
        if input_array[i] & 1:
            odd_nums.append(input_array[i])
    # Pad with zeros
    while len(odd_nums) < MAX_LEN:
        odd_nums.append(0)
    return odd_nums, len(odd_nums)

def write_array(dut, name, vals, width):
    """Write values to array port element by element"""
    for i in range(MAX_LEN):
        v = vals[i] if i < len(vals) else 0
        getattr(dut, f"{name}_{i}").value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_filter_odd(dut):
    # Start clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational circuit - no clock needed
        dut.rst_n.value = 1
        if has_signal(dut, 'start'):
            dut.start.value = 0

    # Test cases
    test_cases = [
        (list(range(1, 11)), "1-10"),  # [1,2,...,10]
        ([10, 20, 45, 67, 84, 93], "10-93"),
        ([5, 7, 9, 8, 6, 4, 3], "mixed"),
        ([0] * 16, "all zeros"),
    ]

    passed = 0
    failed = 0

    for idx, (raw_input, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx + 1}: {desc}")
        
        # Prepare input
        in_len = len(raw_input)
        in_arr = create_test_input(in_len)
        # Fill first part with actual values
        for i, v in enumerate(raw_input):
            in_arr[i] = v
        
        # Get expected
        exp_arr, exp_count = filter_odd_expected(raw_input, in_len)
        
        try:
            # Write inputs
            if has_signal(dut, 'in_len'):
                dut.in_len.value = clamp_to_width(in_len, 4)
            
            for i in range(MAX_LEN):
                val = in_arr[i]
                if has_signal(dut, f'in_arr_{i}'):
                    getattr(dut, f'in_arr_{i}').value = clamp_to_width(val, DATA_WIDTH)
                elif has_signal(dut, 'in_arr'):
                    # Try array of wires
                    dut.in_arr[i].value = clamp_to_width(val, DATA_WIDTH)
            
            # Trigger if sequential
            if is_seq:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                
                if has_signal(dut, 'in_valid'):
                    dut.in_valid.value = 1
                    await RisingEdge(dut.clk)
                    dut.in_valid.value = 0
                
                # Wait for done
                done = False
                for cycle in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if has_signal(dut, 'out_valid'):
                        if is_value_defined(dut.out_valid.value) and int(dut.out_valid.value) == 1:
                            done = True
                            break
                
                if not done:
                    raise TestFailure(f"Timeout waiting for out_valid")
            else:
                # Combinational - wait a bit
                await Timer(100, units='ns')
            
            # Read outputs
            if has_signal(dut, 'out_count'):
                out_count = int(dut.out_count.value)
            else:
                out_count = 0
            
            # Read output array
            out_arr = []
            for i in range(MAX_LEN):
                if has_signal(dut, f'out_arr_{i}'):
                    val = int(getattr(dut, f'out_arr_{i}').value)
                    out_arr.append(val)
                elif has_signal(dut, 'out_arr'):
                    try:
                        val = int(dut.out_arr[i].value)
                        out_arr.append(val)
                    except Exception:
                        out_arr.append(0)
                else:
                    out_arr.append(0)
            
            # Check results
            actual_odd = [v for v in raw_input if v & 1]
            
            if out_count != exp_count:
                raise TestFailure(f"Count mismatch: expected {exp_count}, got {out_count}")
            
            # Compare non-zero entries
            for i in range(exp_count):
                if i >= len(out_arr):
                    raise TestFailure(f"Missing output at index {i}")
                if out_arr[i] != exp_arr[i]:
                    raise TestFailure(f"out_arr[{i}]: expected {exp_arr[i]}, got {out_arr[i]}")
            
            # Check remaining entries are zero
            for i in range(exp_count, MAX_LEN):
                if i < len(out_arr) and out_arr[i] != 0:
                    raise TestFailure(f"Non-zero at padding index {i}: {out_arr[i]}")
            
            cocotb.log.info(f"  PASS: Found {out_count} odd numbers")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
