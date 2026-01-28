import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    """Clamp value to bit width for unsigned"""
    return min((1 << bits) - 1, max(0, v))

def clamp_signed(v, bits):
    """Clamp signed value to bit width"""
    min_val = -(1 << (bits - 1))
    max_val = (1 << (bits - 1)) - 1
    return min(max_val, max(min_val, v))

def to_signed(val, bits):
    """Convert signed Python int to unsigned for HDL"""
    if val < 0:
        return val + (1 << bits)
    return val

def from_signed(val, bits):
    """Convert unsigned HDL value to signed Python int"""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_array_for_bus(values, bits=8, positions=8):
    """Pack array values into bit representation"""
    packed = 0
    for i in range(min(len(values), positions)):
        val = clamp_signed(values[i], bits)
        packed |= (to_signed(val, bits) & ((1 << bits) - 1)) << (i * bits)
    return packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sub_list(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational, no clock needed
        await Timer(100, units='ns')
    
    test_cases = [
        ([1, 2, 3], [4, 5, 6], 3, [-3, -3, -3], "Basic negative"),
        ([1, 2], [3, 4], 2, [-2, -2], "Small arrays"),
        ([90, 120], [50, 70], 2, [40, 50], "Large positive"),
        ([0, 0, 0, 0], [0, 0, 0, 0], 4, [0, 0, 0, 0], "All zeros"),
        ([-10, 20], [5, -5], 2, [-15, 25], "Mixed signs"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr1, arr2, length, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set up inputs
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(length, 4)
            
            # Handle array input - check for individual ports or array
            if has_signal(dut, 'arr1_0'):
                # Individual port per element
                for idx in range(MAX_ARRAY_SIZE):
                    port_name = f'arr1_{idx}'
                    if has_signal(dut, port_name):
                        val = arr1[idx] if idx < len(arr1) else 0
                        dut.__setattr__(port_name).value = to_signed(clamp_signed(val, DATA_WIDTH), DATA_WIDTH)
                
                for idx in range(MAX_ARRAY_SIZE):
                    port_name = f'arr2_{idx}'
                    if has_signal(dut, port_name):
                        val = arr2[idx] if idx < len(arr2) else 0
                        dut.__setattr__(port_name).value = to_signed(clamp_signed(val, DATA_WIDTH), DATA_WIDTH)
            elif has_signal(dut, 'arr1'):
                # Packed array
                dut.arr1.value = pack_array_for_bus(arr1, DATA_WIDTH, MAX_ARRAY_SIZE)
                dut.arr2.value = pack_array_for_bus(arr2, DATA_WIDTH, MAX_ARRAY_SIZE)
            
            # Start operation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                # Combinational logic
                await Timer(100, units='ns')
            
            # Read results
            actual = []
            if has_signal(dut, 'result_0'):
                # Individual output ports
                for idx in range(length):
                    port_name = f'result_{idx}'
                    if has_signal(dut, port_name):
                        val = safe_int(getattr(dut, port_name).value)
                        actual.append(from_signed(val, DATA_WIDTH))
            elif has_signal(dut, 'result'):
                # Packed array
                packed = safe_int(dut.result.value)
                for idx in range(length):
                    val = (packed >> (idx * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1)
                    actual.append(from_signed(val, DATA_WIDTH))
            
            # Verify
            if len(actual) != length:
                raise TestFailure(f"Expected {length} results, got {len(actual)}")
            
            for idx in range(length):
                if actual[idx] != expected[idx]:
                    raise TestFailure(f"Element {idx}: expected {expected[idx]}, got {actual[idx]}")
            
            cocotb.log.info(f"  PASS: {actual}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")