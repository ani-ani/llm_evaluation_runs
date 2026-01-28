import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2048):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

DATA_WIDTH, CLK_NS, MAX_CYCLES = 32, 10, 2048

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_jeopardy_ai(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (10, 5, 2, "Small case"),
        (2020, 2020, 1, "Large n"),
        (1, 0, 0, "Base case X=1"),
        (2, 2, 1, "X=2"),
        (6, 4, 2, "X=6"),
        (35, 7, 3, "X=35"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (X, exp_n, exp_k, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (X={X})")
        try:
            # Set inputs
            if has_signal(dut, 'X'):
                dut.X.value = clamp_to_width(X, DATA_WIDTH)
            
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational module
                await Timer(100, units='ns')
            
            # Check results
            if not is_value_defined(dut.done.value):
                raise TestFailure("Done signal undefined")
            
            if not has_signal(dut, 'valid') or not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal undefined")
            
            valid = int(dut.valid.value)
            if valid == 0:
                raise TestFailure(f"Valid is 0 for X={X}")
            
            result_n = int(dut.n.value)
            result_k = int(dut.k.value)
            
            if result_n != exp_n or result_k != exp_k:
                raise TestFailure(f"Expected ({exp_n}, {exp_k}), got ({result_n}, {result_k})")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Test invalid case (X too large, > C(64,32) ≈ 1.8e18)
    # Using scaled X = 2^32-1 which is still valid, but to test invalid
    # we need a value larger than max C. Since we scale to 32-bit,
    # we test with X=0 (invalid) and expect valid=0
    cocotb.log.info("Test Invalid: X=0")
    try:
        if has_signal(dut, 'X'):
            dut.X.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        
        if has_signal(dut, 'valid') and is_value_defined(dut.valid.value):
            valid = int(dut.valid.value)
            if valid != 0:
                raise TestFailure(f"Expected valid=0 for X=0, got valid={valid}")
        passed += 1
    except TestFailure as e:
        cocotb.log.error(f"FAIL: {e}")
        failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
