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

# Helper to wait for done signal
async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done signal")

# Helper to reset DUT
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Helper to encode string into 128-bit vector
# Order: MSB = first char (index 0)
def encode_expression(s, max_len=16):
    val = 0
    # Pad or truncate to max_len
    if len(s) > max_len:
        s = s[:max_len]
    
    for i, char in enumerate(s):
        # Index 0 is MSB
        # i=0 -> shift by (max_len-1)*8
        shift = (max_len - 1 - i) * 8
        val |= (ord(char) << shift)
    return val

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_balanced_parentheses(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational or async - handle appropriately
        await Timer(100, units='ns')

    test_cases = [
        # (Expression, Expected Result, Description)
        ("{()}[{}]", 1, "Balanced simple nested"),
        ("{()}[{]", 0, "Mismatched closing bracket"),
        ("{()}[{}][]({})", 1, "Complex balanced"),
        ("([)]", 0, "Crossed brackets"),
        ("((", 0, "Too many open"),
        ("))", 0, "Too many close"),
        ("", 1, "Empty string"),
        ("[]", 1, "Simple pair"),
        ("{", 0, "Single open"),
        (")", 0, "Single close"),
    ]

    passed = 0
    failed = 0

    for expr_str, expected, desc in test_cases:
        cocotb.log.info(f"Testing: {desc} ('{expr_str}')")
        
        # 1. Prepare inputs
        length = len(expr_str)
        packed_expr = encode_expression(expr_str, max_len=16)
        
        # 2. Drive inputs
        dut.length.value = clamp_to_width(length, 4)
        dut.expr.value = packed_expr
        
        if has_signal(dut, 'clk'):
            # Sequential logic
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            try:
                await wait_for_done(dut)
            except TestFailure as e:
                cocotb.log.error(f"FAIL: {desc} - {e}")
                failed += 1
                continue
            
            # Check result
            if not is_value_defined(dut.result.value):
                cocotb.log.error(f"FAIL: {desc} - Result signal undefined")
                failed += 1
                continue
                
            result = int(dut.result.value)
        else:
            # Combinational logic (should be instant)
            await Timer(10, units='ns')
            if not is_value_defined(dut.result.value):
                cocotb.log.error(f"FAIL: {desc} - Result signal undefined")
                failed += 1
                continue
            result = int(dut.result.value)

        if result == expected:
            cocotb.log.info(f"PASS: {desc} - Got {result}")
            passed += 1
        else:
            cocotb.log.error(f"FAIL: {desc} - Expected {expected}, got {result}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")
