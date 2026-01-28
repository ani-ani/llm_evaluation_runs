import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# Helper for Python digit product
def digit_product_final(n):
    while n >= 10:
        prod = 1
        while n > 0:
            d = n % 10
            if d != 0:
                prod *= d
            n //= 10
        n = prod
    return n  # returns 1-9

def python_counts(L, R):
    cnt = [0] * 9
    for x in range(L, R + 1):
        d = digit_product_final(x)
        if 1 <= d <= 9:
            cnt[d - 1] += 1
    return cnt

# Scaling: use 16-bit numbers for test
DATA_WIDTH = 16
MAX_BITS = 16
CLK_NS = 10
MAX_CYCLES = 500  # allow more for DP

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
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

async def read_counts(dut):
    counts = []
    for i in range(9):
        sig = getattr(dut, f'count_{i}')
        if is_value_defined(sig.value):
            counts.append(int(sig.value))
        else:
            counts.append(0)
    return counts

async def write_inputs(dut, L, R):
    # Clamp to 16-bit
    L = clamp_to_width(L, DATA_WIDTH)
    R = clamp_to_width(R, DATA_WIDTH)
    if has_signal(dut, 'L'):
        dut.L.value = L
    if has_signal(dut, 'R'):
        dut.R.value = R
    else:
        # Alternative naming
        if hasattr(dut, 'L_in'):
            dut.L_in.value = L
        if hasattr(dut, 'R_in'):
            dut.R_in.value = R

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_digit_product(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
    else:
        # Combinational
        pass

    # Reset
    if has_signal(dut, 'rst_n'):
        await reset_dut(dut, 2)
    else:
        await Timer(10, units='ns')

    # Test cases: small numbers for Python verification
    test_cases = [
        (1, 9, "digits 1-9"),
        (10, 20, "small range"),
        (50, 60, "50-60"),
        (808, 808, "single number 808"),
        (1, 100, "1-100 full"),
    ]

    passed = 0
    failed = 0

    for L, R, desc in test_cases:
        # Scale down for Verilog if needed, keep small
        # Python reference
        exp = python_counts(L, R)
        
        cocotb.log.info(f"Test {desc}: L={L}, R={R}")
        cocotb.log.info(f"Expected: {exp}")

        try:
            # Write inputs
            await write_inputs(dut, L, R)

            # Trigger
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # Wait for done
                await wait_for_done(dut)
            else:
                # Combinational - wait stabilization
                await Timer(100, units='ns')

            # Read results
            if has_signal(dut, 'count_0'):
                result = await read_counts(dut)
            elif has_signal(dut, 'count'):
                # Packed? Assume 9x16 packed into 144 bits
                val = int(dut.count.value)
                result = []
                for i in range(9):
                    result.append((val >> (i*16)) & 0xFFFF)
            else:
                raise TestFailure("No count output found")

            cocotb.log.info(f"Got: {result}")

            # Compare
            for i in range(9):
                if result[i] != exp[i]:
                    raise TestFailure(f"count[{i+1}]: expected {exp[i]}, got {result[i]}")

            passed += 1
            cocotb.log.info(f"PASS: {desc}")

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")