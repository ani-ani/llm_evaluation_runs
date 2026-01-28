import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helper Functions ---
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def to_signed(val, bits):
    val = val & ((1 << bits) - 1)  # Ensure within width
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return (1 << bits) + val
    return val

def has_signal(dut, name):
    return hasattr(dut, name)

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# --- Constants ---
CLK_NS = 10
MAX_CYCLES = 200
ASCII_OPEN = 40
ASCII_CLOSE = 41
DATA_WIDTH = 8

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    dut.seq_in.value = 0
    dut.len.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# --- Test Helpers ---
def seq_to_bits(seq_str):
    bits = 0
    for i, char in enumerate(seq_str):
        ascii_val = ASCII_OPEN if char == '(' else ASCII_CLOSE
        bits |= (ascii_val << (i * DATA_WIDTH))
    return bits

def check_expected(seq):
    # Python reference implementation
    if len(seq) == 0:
        return 1
    if len(seq) % 2 != 0:
        return 0
    
    balance = 0
    min_balance = 0
    for char in seq:
        if char == '(':
            balance += 1
        else:
            balance -= 1
            if balance < min_balance:
                min_balance = balance
        if balance < -2: # Optimization: if we go below -2, 1 move can't save it
            return 0
    
    if balance == 0 and min_balance >= -1:
        return 1
    return 0

# --- Cocotb Test ---
@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_bracket_fixer(dut):
    """Test the bracket sequence fixer module"""
    
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        dut.rst_n.value = 1

    # Test Cases: (sequence, expected_result)
    test_cases = [
        ("", 1),           # Empty
        ("(", 0),          # Odd length
        (")", 0),          # Odd length
        ("()", 1),         # Correct
        (")(", 1),         # Fixable with move
        ("(()", 0),        # Not fixable
        ("())", 0),        # Not fixable
        ("((()))", 1),     # Correct
        (")))(((", 0),     # Impossible balance
        ("())(()", 1),     # Might be fixable? Let's check: balance: 1,0,-1,0,1,0. Min -1. Final 0. Yes.
        ("((((", 0),       # Final balance != 0
        ("))))(((", 0),    # High min
    ]

    # Add random tests
    random.seed(42)
    for _ in range(20):
        length = random.randint(0, 16)
        if length % 2 == 1:
            continue
        seq = ''.join(random.choice(['(', ')']) for _ in range(length))
        expected = check_expected(seq)
        test_cases.append((seq, expected))

    passed = 0
    failed = 0

    for i, (seq, expected) in enumerate(test_cases):
        # Prepare inputs
        seq_bits = seq_to_bits(seq)
        seq_len = len(seq)

        cocotb.log.info(f"Test {i+1}: Sequence='{seq}', Len={seq_len}, Exp={'Yes' if expected else 'No'}")

        try:
            # Apply inputs
            dut.seq_in.value = seq_bits
            dut.len.value = seq_len

            # Start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
            else:
                # Combinational? Wait a bit for propagation
                await Timer(50, units='ns')

            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            res_val = int(dut.result.value)
            
            if res_val != expected:
                raise TestFailure(f"Expected {'Yes' if expected else 'No'}, got {'Yes' if res_val else 'No'}")
            
            passed += 1
            
            # Reset for next test
            if has_signal(dut, 'clk'):
                await reset_dut(dut)

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            # Continue testing
            if has_signal(dut, 'clk'):
                await reset_dut(dut)

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
