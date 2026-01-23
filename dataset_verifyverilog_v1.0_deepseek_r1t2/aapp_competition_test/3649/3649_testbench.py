import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_subsequence_string(dut):
    test_cases = [
        (3, 4, 2, 1, [0,1,0,0,1]),
        (5, 0, 0, 5, None),
        (1, 2, 2, 1, [0,1,1,0]),
        (1, 0, 0, 0, [0,0]),
        (0, 0, 0, 0, [1]),
        (0, 0, 0, 1, [1,1]),
        (1, 0, 0, 1, None),
    ]
    
    for a, b, c, d, expected in test_cases:
        # Set inputs
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        dut.d.value = d
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Read outputs
        valid = int(dut.valid.value)
        length = int(dut.length.value)
        
        if valid:
            if expected is None:
                raise TestFailure(f'Test {a},{b},{c},{d}: expected impossible but got valid')
            # Check length
            if length > 16:
                raise TestFailure(f'Length {length} exceeds max 16')
            # Read bits
            bits = []
            for i in range(length):
                bits.append(int(dut.string_bits[i].value))
            if bits != expected:
                raise TestFailure(f'Test {a},{b},{c},{d}: expected {expected}, got {bits}')
        else:
            if expected is not None:
                raise TestFailure(f'Test {a},{b},{c},{d}: expected valid but got impossible')