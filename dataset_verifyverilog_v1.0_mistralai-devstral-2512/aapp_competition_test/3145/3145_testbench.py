import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 200000  # 200k cycles max for simulation

# Helper Functions
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Python Reference Implementation (Scaled to 16-bit)
def python_reference(X, A, B, allowed_str):
    # Convert allowed string to set of characters
    allowed_set = set(allowed_str)
    count = 0
    for n in range(A, B + 1):
        if n % X == 0:
            # Check digits
            if n == 0:
                if '0' in allowed_set:
                    count += 1
            else:
                temp = n
                valid = True
                while temp > 0:
                    digit = temp % 10
                    if str(digit) not in allowed_set:
                        valid = False
                        break
                    temp //= 10
                if valid:
                    count += 1
    return count

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

def allowed_str_to_mask(s):
    mask = 0
    for char in s:
        if '0' <= char <= '9':
            mask |= (1 << (ord(char) - ord('0')))
    return mask

# Test Cases (scaled inputs)
TEST_CASES = [
    # (X, A, B, allowed_str, expected_result)
    (2, 1, 20, "0123456789", 10),   # Sample 1
    (6, 100, 9294, "23689", 111),   # Sample 2
    (5, 4395, 65535, "12346789", 0), # Sample 3 (Clamped B to 65535)
    (3, 1, 100, "0123456789", 33), # Simple case
    (7, 10, 50, "01", 0),          # No multiples with only 0,1
    (1, 1, 100, "9", 1),           # Only 9
    (10, 0, 100, "0", 11),         # Multiples of 10 ending in 0 (0, 10, 20, ..., 100) - Note: 0 is included if A=0
]

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_zvonko_digits(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic assumed
        await Timer(10, units='ns')

    passed = 0
    failed = 0

    for i, (X, A, B, allowed_str, expected) in enumerate(TEST_CASES):
        # Scale inputs to 16-bit if they exceed (though our test cases are small)
        X_in = clamp_to_width(X, DATA_WIDTH)
        A_in = clamp_to_width(A, DATA_WIDTH)
        B_in = clamp_to_width(B, DATA_WIDTH)
        mask = allowed_str_to_mask(allowed_str)
        
        cocotb.log.info(f"Test {i+1}: X={X_in}, A={A_in}, B={B_in}, Allowed={allowed_str}, Expected={expected}")

        try:
            # Input assignment
            dut.X.value = X_in
            dut.A.value = A_in
            dut.B.value = B_in
            if has_signal(dut, 'allowed'):
                dut.allowed.value = mask
            
            # Trigger start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: wait for settle
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
