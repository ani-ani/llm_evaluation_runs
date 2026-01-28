import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- Helpers ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# --- Fixed Point Math ---
FRAC_BITS = 16
INT_BITS = 16
SCALE = 1 << FRAC_BITS

def float_to_fixed(f):
    return int(f * SCALE)

def fixed_to_float(v):
    return v / SCALE

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_en.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bug_fixing(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases based on prompt
    test_cases = [
        # (B, T, f, [(p, s)...], expected_float)
        (1, 2, 0.95, [(0.7, 50)], 44.975),
        (2, 2, 0.50, [(0.75, 100), (0.75, 20)], 95.625),
    ]
    
    for tc_idx, (B, T, f, bugs, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {tc_idx+1}: B={B}, T={T}, f={f}")
        
        # 1. Load Parameters
        dut.B.value = B
        dut.T.value = T
        dut.f_in.value = float_to_fixed(f)
        await RisingEdge(dut.clk)
        
        # 2. Load Bugs
        dut.load_en.value = 1
        for p, s in bugs:
            dut.p_in.value = float_to_fixed(p)
            dut.s_in.value = s
            await RisingEdge(dut.clk)
        dut.load_en.value = 0
        await RisingEdge(dut.clk)
        
        # 3. Start Computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 4. Wait for Done (max T cycles + overhead)
        max_cycles = T + 10
        done = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
                
        if not done:
            raise TestFailure(f"Test {tc_idx+1} timed out")
            
        # 5. Check Result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal undefined")
            
        result_val = int(dut.result.value)
        # Convert back to float for comparison
        # result_val is Q16.16
        result_float = result_val / (1 << 16)
        
        cocotb.log.info(f"Expected: {expected}, Got: {result_float}")
        
        if abs(result_float - expected) > 1e-4:
            raise TestFailure(f"Value mismatch: expected {expected}, got {result_float}")

    cocotb.log.info("All tests passed!")
