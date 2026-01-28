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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def decode_combination(packed, n):
    """Extract 2-bit fields from packed 8-bit value"""
    vals = []
    for i in range(n):
        val = (packed >> (2*i)) & 0x3
        vals.append(val)
    return tuple(vals)

def expected_combinations(n):
    """Generate expected combinations as tuples of integers (0,1,2)"""
    if n == 1:
        return [(0,), (1,), (2,)]
    elif n == 2:
        return [(0,0), (0,1), (0,2), (1,1), (1,2), (2,2)]
    elif n == 3:
        return [(0,0,0), (0,0,1), (0,0,2), (0,1,1), (0,1,2), (0,2,2), (1,1,1), (1,1,2), (1,2,2), (2,2,2)]
    else:
        return []

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_combinations(dut):
    DATA_WIDTH, ARRAY_SIZE, CLK_NS = 8, 10, 10
    
    if not has_signal(dut, 'clk'):
        raise TestFailure("Sequential module required")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (1, "n=1"),
        (2, "n=2"),
        (3, "n=3"),
    ]
    
    passed = failed = 0
    
    for i, (n, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            dut.n.value = n
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut, max_cycles=200)
            
            out_count = int(dut.out_count.value)
            expected_count = len(expected_combinations(n))
            
            if out_count != expected_count:
                raise TestFailure(f"Expected {expected_count} combinations, got {out_count}")
            
            # Check each output combination
            for idx in range(expected_count):
                out_val = int(getattr(dut, f'out_array_{idx}').value)
                decoded = decode_combination(out_val, n)
                expected = expected_combinations(n)[idx]
                
                if decoded != expected:
                    raise TestFailure(f"Combination {idx}: expected {expected}, got {decoded}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {out_count} combinations correct")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")