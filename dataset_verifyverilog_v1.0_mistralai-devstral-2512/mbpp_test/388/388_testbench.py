import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, CLK_NS, MAX_CYCLES = 16, 10, 20

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_highest_power_of_2(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (0, 0, "n=0"),
        (1, 1, "n=1"),
        (2, 2, "n=2"),
        (3, 2, "n=3"),
        (7, 4, "n=7"),
        (8, 8, "n=8"),
        (10, 8, "n=10"),
        (15, 8, "n=15"),
        (16, 16, "n=16"),
        (19, 16, "n=19"),
        (31, 16, "n=31"),
        (32, 32, "n=32"),
        (100, 64, "n=100"),
        (1023, 512, "n=1023"),
        (1024, 1024, "n=1024"),
        (32767, 16384, "n=32767"),
        (32768, 32768, "n=32768"),
        (65535, 32768, "n=65535"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n_val})")
        try:
            if has_signal(dut, 'clk'):
                dut.n.value = clamp_to_width(n_val, DATA_WIDTH)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                if result != exp:
                    raise TestFailure(f"Expected {exp}, got {result}")
            else:
                dut.n.value = clamp_to_width(n_val, DATA_WIDTH)
                await Timer(100, units='ns')
                result = int(dut.result.value)
                if result != exp:
                    raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
