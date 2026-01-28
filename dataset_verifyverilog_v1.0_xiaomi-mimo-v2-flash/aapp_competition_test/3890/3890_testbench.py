import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

MOD = 1000000007

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
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_expected(n, k):
    """Compute k^(k-1) * (n-k)^(n-k) % MOD"""
    if k > n or k < 1:
        return 0
    if k == 1:
        # 1^0 = 1
        if n == 1:
            return 1
        return pow(n-1, n-1, MOD)
    
    part1 = pow(k, k-1, MOD)
    part2 = pow(n-k, n-k, MOD)
    return (part1 * part2) % MOD

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_penguin_walk(dut):
    # Setup clock
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just wait
        await Timer(100, units='ns')
    
    test_cases = [
        (5, 2, 54),
        (7, 4, 1728),
        (8, 5, 16875),
        (8, 1, 823543),
        (10, 7, 3176523),
        (12, 8, 536870912),
        (50, 2, 628702797),
        (100, 8, 331030906),
        (1000, 8, 339760446),
        (999, 7, 490075342),
        (685, 7, 840866481),
        (975, 8, 531455228),
        (475, 5, 449471303),
        (227, 6, 407444135),
        (876, 8, 703293724),
        (1000, 1, 760074701),
        (1000, 2, 675678679),
        (1000, 3, 330155123),
        (1000, 4, 660270610),
        (1000, 5, 583047503),
        (1000, 6, 834332109),
        (657, 3, 771999480),
        (137, 5, 160909830),
        (8, 8, 2097152),
        (9, 8, 2097152),
        (1, 1, 1),
        (2, 1, 1),
        (2, 2, 2),
        (3, 3, 9),
        (473, 4, 145141007),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, k_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, k={k_val}, expected={expected}")
        
        try:
            # Set inputs
            if has_signal(dut, 'n_in'):
                dut.n_in.value = clamp_to_width(n_val, 10)
            if has_signal(dut, 'k_in'):
                dut.k_in.value = clamp_to_width(k_val, 10)
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Module missing 'result' output")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined (X or Z)")
            
            result = int(dut.result.value)
            
            # Check result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTotal: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")