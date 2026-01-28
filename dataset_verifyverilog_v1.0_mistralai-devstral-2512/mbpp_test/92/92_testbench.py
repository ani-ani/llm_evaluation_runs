import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 100

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_is_undulating(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_number, expected_result, description)
    # 1212121: 1-2-1-2-1-2-1 (Pattern '12', length 7) -> True
    # 1991: 1-9-9-1 (Pattern breaks at 3rd digit) -> False
    # 121: 1-2-1 (Pattern '12', length 3) -> True
    # Edge cases
    test_cases = [
        (1212121, 1, "7-digit pattern 1212121"),
        (1991, 0, "4-digit 1991 (breaks pattern)"),
        (121, 1, "3-digit pattern 121"),
        (12, 0, "2-digit (too short)"),
        (1, 0, "1-digit (too short)"),
        (1111, 1, "4-digit pattern 1111 (11)"),
        (1212, 1, "4-digit pattern 1212 (12)"),
        (1213, 0, "4-digit 1213 (breaks)"),
        (0, 0, "Zero (1-digit)"),
        (98989, 1, "5-digit pattern 98989 (98)"),
        (101010, 1, "6-digit pattern 101010 (10)"),
    ]
    
    passed = failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (Input: {inp})")
        try:
            # Set inputs
            dut.num.value = inp
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational fallback (should not happen for seq spec)
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.is_undulating.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.is_undulating.value)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
