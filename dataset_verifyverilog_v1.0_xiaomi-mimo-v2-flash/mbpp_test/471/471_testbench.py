import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, MAX_LEN, CLK_NS, MAX_CYCLES = 16, 16, 10, 1000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'valid_in'): dut.valid_in.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def send_array(dut, arr, n):
    """Send array elements sequentially via arr_in/valid_in"""
    if has_signal(dut, 'n'):
        dut.n.value = clamp_to_width(n, DATA_WIDTH)
    
    for i, val in enumerate(arr):
        if has_signal(dut, 'valid_in'):
            dut.valid_in.value = 1
        if has_signal(dut, 'arr_in'):
            dut.arr_in.value = clamp_to_width(val, DATA_WIDTH)
        await RisingEdge(dut.clk)
        if has_signal(dut, 'valid_in'):
            dut.valid_in.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_remainder(dut):
    # Check required signals
    required_signals = ['clk', 'rst_n', 'start', 'arr_in', 'valid_in', 'len', 'n', 'result', 'done', 'ready']
    missing = [s for s in required_signals if not has_signal(dut, s)]
    if missing:
        raise TestFailure(f"Missing signals: {missing}")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Verify ready state
    if not int(dut.ready.value):
        raise TestFailure("DUT not ready after reset")
    
    test_cases = [
        ([100, 10, 5, 25, 35, 14], 11, 9, "Test 1"),
        ([1, 1, 1], 1, 0, "Test 2"),
        ([1, 2, 1], 2, 0, "Test 3")
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running {desc}: arr={arr}, n={n}, expected={expected}")
        
        try:
            # Start pulse
            dut.start.value = 1
            dut.len.value = len(arr)
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Check ready goes low
            if int(dut.ready.value):
                raise TestFailure("ready should be 0 after start")
            
            # Send array elements
            await send_array(dut, arr, n)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} - Result {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL {desc}: {e}")
            failed += 1
        
        # Wait for ready to be high again
        if i < len(test_cases) - 1:
            for _ in range(10):
                await RisingEdge(dut.clk)
                if int(dut.ready.value):
                    break
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")