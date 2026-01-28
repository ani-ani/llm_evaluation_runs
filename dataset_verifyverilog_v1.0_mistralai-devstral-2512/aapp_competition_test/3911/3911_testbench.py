import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 17, 17, 10, 1000

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

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

async def read_array(dut, name, length, width):
    result = []
    for i in range(length):
        sig = dut.__getattr__(name)[i]
        if is_value_defined(sig.value):
            result.append(int(sig.value))
        else:
            result.append(0)
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_slime_machine(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("Sequential design required")
    
    # Test cases: (n, expected_values, description)
    test_cases = [
        (1, [1], "Single slime"),
        (2, [2], "Two slimes merge"),
        (3, [2, 1], "Three slimes"),
        (8, [4], "Power of two"),
        (100000, [17, 16, 11, 10, 8, 6], "Large value"),
        (0, [], "Zero input"),
        (15, [4, 3, 2, 1], "15 = 1111"),
    ]
    
    passed = failed = 0
    
    for i, (n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n})")
        try:
            # Set input
            dut.n_in.value = clamp_to_width(n, 17)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=200)
            
            # Read results
            if not is_value_defined(dut.result_len.value):
                raise TestFailure("result_len undefined")
            
            result_len = int(dut.result_len.value)
            result_vals = await read_array(dut, 'result_v', result_len, 5)
            
            # Verify
            if result_len != len(expected):
                raise TestFailure(f"Length mismatch: expected {len(expected)}, got {result_len}")
            
            for j, (got, exp) in enumerate(zip(result_vals, expected)):
                if got != exp:
                    raise TestFailure(f"Index {j}: expected {exp}, got {got}")
            
            cocotb.log.info(f"  PASS: {result_vals}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(10, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    
    cocotb.log.info(f"All {passed} tests passed")
