import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_expected_gifts(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Precomputed Q8.8 values (scaled by 256)
    # n: [2..16]
    # E(2)=3.0 -> 768
    # E(3)=5.3333 -> 1365
    # E(4)=8.0 -> 2048
    # E(5)=10.6666 -> 2730
    # E(16)=40.0 -> 10240
    expected_vals = {
        2: 768,
        3: 1365,
        4: 2048,
        5: 2730,
        6: 3413,
        7: 4096,
        8: 4779,
        9: 5461,
        10: 6144,
        11: 6827,
        12: 7509,
        13: 8192,
        14: 8875,
        15: 9557,
        16: 10240
    }
    
    passed = 0
    failed = 0
    
    for n_val, expected_int in expected_vals.items():
        cocotb.log.info(f"Testing n={n_val}")
        
        # Set input n
        dut.n.value = n_val
        
        # Assert start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (or 1 cycle as per spec)
        # Since it's a registered LUT, result is valid 1 cycle after start
        await RisingEdge(dut.clk)
        
        # Check result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Result undefined for n={n_val}")
            failed += 1
            continue
            
        result = int(dut.result.value)
        
        # Allow small rounding errors due to truncation in LUT vs actual float
        # The values are pre-scaled. Let's check exact match for provided values.
        # If the problem expects exact integer matching scaled values:
        if result == expected_int:
            passed += 1
        else:
            cocotb.log.error(f"FAIL for n={n_val}: Expected {expected_int}, got {result}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
