import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
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
    # For signed values, clamp to signed range if necessary, but here we just clamp unsigned for assignments usually
    # For signed inputs, we need to map python int to HDL bit representation
    # The function here is for clamping unsigned to width
    return min((1 << bits) - 1, max(0, v))

# Testbench configuration
DATA_WIDTH = 8
ARRAY_SIZE = 16
LEN_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 500

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array_sequential(dut, arr, width):
    """Write array elements to dut sequential signals arr_in_0, arr_in_1, etc."""
    for i, val in enumerate(arr):
        if i >= ARRAY_SIZE: break
        sig_name = f'arr_in_{i}'
        if has_signal(dut, sig_name):
            # Convert signed python int to HDL representation
            v = val & ((1 << width) - 1)  # Keep lower 8 bits
            getattr(dut, sig_name).value = v
        else:
            # Assume packed array or unpacked, try accessing index
            try:
                dut.arr_in[i].value = val & ((1 << width) - 1)
            except (AttributeError, IndexError):
                pass

async def get_expected_count(arr, target_sum, length):
    count = 0
    for i in range(length):
        for j in range(i + 1, length):
            if arr[i] + arr[j] == target_sum:
                count += 1
    return count

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_pair_count(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational, just wait
        await Timer(100, units='ns')

    test_cases = [
        ([1, 1, 1, 1], 2, 4),  # Test 1: 6 pairs
        ([1, 5, 7, -1, 5], 6, 5),  # Test 2: 3 pairs
        ([1, -2, 3], 1, 3),  # Test 3: 1 pair
        ([-1, -2, 3], -3, 3)   # Test 4: 1 pair
    ]

    passed = 0
    failed = 0

    for i, (input_arr, target, length) in enumerate(test_cases):
        desc = f"Test {i+1}: arr={input_arr}, sum={target}"
        cocotb.log.info(desc)
        
        try:
            # Calculate expected
            expected = get_expected_count(input_arr, target, length)
            
            # Write inputs
            await write_array_sequential(dut, input_arr, DATA_WIDTH)
            
            if has_signal(dut, 'len'):
                dut.len.value = length
            
            if has_signal(dut, 'target_sum'):
                # Convert signed target to HDL value
                target_hdl = target & 0xFF
                dut.target_sum.value = target_hdl
            
            # Trigger
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done = False
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                
                if not done:
                    raise TestFailure(f"Timeout waiting for done signal")
            else:
                # Combinational, wait for propagation
                await Timer(100, units='ns')

            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = int(dut.result.value)
            # Handle signed result if applicable, but count should be unsigned
            # Clamp to 8-bit
            result_val = result_val & 0xFF
            
            if result_val != expected:
                raise TestFailure(f"Expected {expected}, got {result_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL ({desc}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
