import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_operations_to_ones(dut):
    DATA_WIDTH = 32
    RESULT_WIDTH = 16
    ARRAY_SIZE = 16
    CLK_NS = 10
    MAX_CYCLES = 300
    
    # Setup clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases: (array_values, len, expected_result, description)
    test_cases = [
        ([2, 2, 3, 4, 6], 5, 5, "Example 1: 5 operations needed"),
        ([2, 4, 6, 8], 4, -1, "Example 2: Impossible - GCD all > 1"),
        ([2, 6, 9], 3, 4, "Example 3: 4 operations needed"),
        ([1, 1, 1, 1], 4, 0, "All 1s: zero operations"),
        ([3], 1, -1, "Single non-1: impossible"),
        ([1], 1, 0, "Single 1: zero operations"),
        ([10, 10, 10, 10], 4, 3, "All 10s: need 3 operations"),
        ([1, 2, 1, 1], 4, 1, "Has 1s: replace non-1 elements"),
        ([6, 10, 15], 3, 4, "Multiple primes: GCD=1, min subarray length 2"),
        ([42, 15, 35], 3, 4, "Example from note: 4 operations"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, arr_len, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set array elements (fixed 16 slots)
            for j in range(ARRAY_SIZE):
                if j < arr_len:
                    dut.arr[j].value = clamp_to_width(arr_vals[j], DATA_WIDTH)
                else:
                    dut.arr[j].value = 0  # Fill unused slots
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(arr_len, 4)
            else:
                cocotb.log.warning("len signal not found, assuming full array")
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("result signal not found")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            raw_result = int(dut.result.value)
            result = to_signed(raw_result, RESULT_WIDTH)
            
            # Special case: -1 is 0xFFFF in 16-bit two's complement
            if expected == -1:
                expected_raw = from_signed(-1, RESULT_WIDTH)
                if raw_result != expected_raw:
                    raise TestFailure(f"Expected -1 (0x{expected_raw:04X}), got {result} (0x{raw_result:04X})")
            else:
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} (raw: 0x{raw_result:04X})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset between tests if sequential
        if is_seq and i < len(test_cases) - 1:
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
