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
    return min((1 << bits) - 1, max(0, v))

# Constants
DATA_WIDTH = 8
MAX_NEG = -(1 << (DATA_WIDTH - 1))  # -128
MAX_POS = (1 << (DATA_WIDTH - 1)) - 1  # 127
CLK_NS = 10
MAX_CYCLES = 100

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure("Timeout waiting for done signal")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_largest_smallest(dut):
    # Setup clock
    if not has_signal(dut, 'clk'):
        dut._log.warning("No 'clk' signal found, skipping sequential test")
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test cases based on the Python function
    test_cases = [
        ([2, 4, 1, 3, 5, 7], None, 1, "Only positives"),
        ([1, 3, 2, 4, 5, 6, -2], -2, 1, "One negative"),
        ([4, 5, 3, 6, 2, 7, -7], -7, 2, "Negative larger mag"),
        ([7, 3, 8, 4, 9, 2, 5, -9], -9, 2, "Mixed"),
        ([], None, None, "Empty"),
        ([0], None, None, "Only zero"),
        ([-1, -3, -5, -6], -1, None, "Only negatives"),
        ([-6, -4, -4, -3, 1], -3, 1, "Mixed specific"),
        ([-6, -4, -4, -3, -100, 1], -3, 1, "Mixed with large neg"),
    ]

    passed = 0
    failed = 0

    for inp, exp_neg, exp_pos, desc in test_cases:
        dut._log.info(f"Test case: {desc} - Input: {inp}")
        
        # Check if input fits in len (4 bits)
        if len(inp) > 15:
            dut._log.warning(f"Skipping test {desc}: Input length {len(inp)} > 15")
            continue

        # Load input into array
        for i in range(16):
            val = inp[i] if i < len(inp) else 0
            # Clamp to signed 8-bit range and handle negative
            clamped = val
            if clamped < -128: clamped = -128
            if clamped > 127: clamped = 127
            
            # Sign extend to 8 bits for Verilog assignment
            if clamped < 0:
                dut.arr[i].value = (1 << 8) + clamped  # 2's complement for 8 bits
            else:
                dut.arr[i].value = clamped

        # Set length
        if has_signal(dut, 'len'):
            dut.len.value = len(inp)
        else:
            # Assume length is determined by input, maybe implicit in interface
            pass

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            dut._log.error(f"Timeout on test {desc}")
            failed += 1
            continue

        # Check outputs
        neg_valid = int(dut.neg_valid.value)
        pos_valid = int(dut.pos_valid.value)
        
        neg_val_raw = int(dut.neg_val.value)
        pos_val_raw = int(dut.pos_val.value)

        # Convert Verilog output back to Python int (signed)
        neg_val = to_signed(neg_val_raw, DATA_WIDTH)
        pos_val = to_signed(pos_val_raw, DATA_WIDTH)

        # Validate
        success = True
        if exp_neg is None:
            if neg_valid != 0:
                dut._log.error(f"Expected no negative, but got valid={neg_valid}, val={neg_val}")
                success = False
        else:
            if neg_valid == 0:
                dut._log.error(f"Expected negative {exp_neg}, but valid=0")
                success = False
            elif neg_val != exp_neg:
                dut._log.error(f"Negative mismatch: expected {exp_neg}, got {neg_val}")
                success = False

        if exp_pos is None:
            if pos_valid != 0:
                dut._log.error(f"Expected no positive, but got valid={pos_valid}, val={pos_val}")
                success = False
        else:
            if pos_valid == 0:
                dut._log.error(f"Expected positive {exp_pos}, but valid=0")
                success = False
            elif pos_val != exp_pos:
                dut._log.error(f"Positive mismatch: expected {exp_pos}, got {pos_val}")
                success = False

        if success:
            passed += 1
        else:
            failed += 1

        # Reset for next test
        await reset_dut(dut)

    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    else:
        dut._log.info(f"All {passed} tests passed!")
