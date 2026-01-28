import cocotb
from cocotb.triggers import Timer, RisingEdge, Join
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 64
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sheldon_counter(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (1, 10, 10, "1-10: all 10 numbers"),
        (70, 75, 1, "70-75: only 73"),
        (0, 0, 0, "0: not Sheldon"),
        (1, 1, 1, "1: is Sheldon"),
        (73, 73, 1, "73: exactly Sheldon"),
        (54, 54, 1, "54: 110110"),
        (1, 100, 18, "1-100: 18 Sheldons"),
        (2015, 2015, 1, "2015: is Sheldon"),
        (1984, 1984, 1, "1984: is Sheldon"),
        (1755, 1755, 1, "1755: is Sheldon"),
        (21, 21, 1, "21: is Sheldon"),
        (42, 42, 1, "42: is Sheldon"),
    ]
    
    passed = failed = 0
    
    for i, (x, y, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set inputs
            if has_signal(dut, 'x_i'):
                dut.x_i.value = x
                dut.y_i.value = y
            elif has_signal(dut, 'x'):
                dut.x.value = x
                dut.y.value = y
            else:
                raise TestFailure("No valid input signals found")
            
            if is_seq:
                # Trigger computation
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    await wait_for_done(dut, MAX_CYCLES)
                else:
                    # If no start, just wait for output to stabilize
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)
            else:
                # Combinational: small delay
                await Timer(100, units='ns')
            
            # Read result
            result_signal = None
            for name in ['result', 'out', 'count', 'sheldon_count']:
                if has_signal(dut, name):
                    result_signal = getattr(dut, name)
                    break
            
            if result_signal is None:
                raise TestFailure("Result signal not found")
            
            if not is_value_defined(result_signal.value):
                raise TestFailure("Result undefined")
            
            result = int(result_signal.value)
            
            # Clamp expected to 16-bit
            exp_clamped = clamp_to_width(exp, 16)
            
            if result != exp_clamped:
                raise TestFailure(f"Expected {exp_clamped}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {desc} -> {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")

# Additional test for large ranges
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sheldon_large_range(dut):
    """Test with large numbers to verify 64-bit handling"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test a range that includes no Sheldons
    test_cases = [
        (10000, 10010, 0, "Large range with no Sheldons"),
        (2**62, 2**62+1000, 0, "Very large range"),
    ]
    
    for x, y, exp, desc in test_cases:
        cocotb.log.info(f"Testing: {desc}")
        
        if has_signal(dut, 'x_i'):
            dut.x_i.value = x
            dut.y_i.value = y
        elif has_signal(dut, 'x'):
            dut.x.value = x
            dut.y.value = y
        
        if is_seq:
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
        else:
            await Timer(100, units='ns')
        
        result_signal = None
        for name in ['result', 'out', 'count']:
            if has_signal(dut, name):
                result_signal = getattr(dut, name)
                break
        
        if result_signal is None:
            raise TestFailure("Result signal not found")
        
        if not is_value_defined(result_signal.value):
            raise TestFailure("Result undefined")
        
        result = int(result_signal.value)
        if result != exp:
            raise TestFailure(f"Expected {exp}, got {result}")
        
        cocotb.log.info(f"  PASS: {result}")