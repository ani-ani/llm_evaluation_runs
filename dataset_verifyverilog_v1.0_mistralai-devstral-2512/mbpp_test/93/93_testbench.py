import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_EXP = 4
RESULT_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=50):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_power_calc(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("Module must be sequential with clock")
    
    test_cases = [
        (3, 4, 81, "power(3,4)=81"),
        (2, 3, 8, "power(2,3)=8"),
        (5, 5, 3125, "power(5,5)=3125"),
        (0, 5, 0, "power(0,5)=0"),
        (5, 0, 1, "power(5,0)=1"),
        (1, 10, 1, "power(1,10)=1"),
        (10, 2, 100, "power(10,2)=100"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (base, exp, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Clamp inputs to bit widths
            dut.a.value = clamp_to_width(base, DATA_WIDTH)
            dut.b.value = clamp_to_width(exp, MAX_EXP)
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            
            # Check overflow flag if expected overflow
            if has_signal(dut, 'overflow'):
                overflow = int(dut.overflow.value)
                if result > ((1 << RESULT_WIDTH) - 1):
                    if overflow != 1:
                        cocotb.log.warning(f"Overflow detected but flag not set: result={result}")
                if overflow == 1:
                    result = (1 << RESULT_WIDTH) - 1  # Clamp to max
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            # Verify done signal is high only for one cycle
            await RisingEdge(dut.clk)
            if int(dut.done.value) == 1:
                raise TestFailure("Done signal stayed high for more than 1 cycle")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    # Additional test for overflow
    cocotb.log.info("Test Overflow: power(15,15)")
    try:
        dut.a.value = 15
        dut.b.value = 15
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        if has_signal(dut, 'overflow'):
            overflow = int(dut.overflow.value)
            if overflow != 1:
                raise TestFailure(f"Overflow flag not set for a=15,b=15, result={result}")
            passed += 1
        else:
            cocotb.log.warning("Overflow signal not present, skipping overflow test")
            passed += 1
    except TestFailure as e:
        cocotb.log.error(f"FAIL: {e}")
        failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    cocotb.log.info(f"All {passed} tests passed")