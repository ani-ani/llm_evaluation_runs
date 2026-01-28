import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

# Helper to convert string to packed bits
async def str_to_packed(dut, port_name, s_str, n_bits):
    packed_val = 0
    for i in range(min(n_bits, len(s_str))):
        # s_str[i] corresponds to bit i (LSB)
        if s_str[i] == 'b':
            packed_val |= (1 << i)
    getattr(dut, port_name).value = clamp_to_width(packed_val, 16)

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fair_nut_strings(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, k, s_str, t_str, expected_output)
    test_cases = [
        (2, 4, "aa", "bb", 6),
        (3, 3, "aba", "bba", 8),
        (4, 5, "abbb", "baaa", 8),
        (1, 1, "a", "a", 1),
        (1, 1000000000, "a", "a", 1),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, s_str, t_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, k={k}, s={s_str}, t={t_str}, expected={expected}")
        
        try:
            # Clamp k to 256 for hardware (as per spec)
            k_hardware = min(k, 256)
            
            # Set inputs
            dut.n.value = n
            dut.k.value = k_hardware
            await str_to_packed(dut, 's', s_str, n)
            await str_to_packed(dut, 't', t_str, n)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=100)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # For hardware that caps k, check against expected capped result if needed
            # In this problem, capping k at 256 shouldn't affect correctness for test cases given
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1
            # Continue to next test
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
