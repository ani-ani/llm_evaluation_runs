import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

# Fixed-point conversion (Q16.16)
def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Convert signed value to unsigned representation
def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

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

async def write_species_params(dut, n, a_list, b_list, d_list, width=16):
    """Write parameters for each species individually"""
    for i in range(n):
        getattr(dut, f'a_{i}').value = clamp_to_width(a_list[i], width)
        getattr(dut, f'b_{i}').value = clamp_to_width(b_list[i], width)
        getattr(dut, f'd_{i}').value = clamp_to_width(d_list[i], width)
    # Zero out remaining species
    for i in range(n, 8):
        getattr(dut, f'a_{i}').value = 0
        getattr(dut, f'b_{i}').value = 0
        getattr(dut, f'd_{i}').value = 0

async def read_allocation(dut, n):
    """Read x_i outputs as Q16.16 fixed-point and convert to float"""
    results = []
    for i in range(n):
        val = int(getattr(dut, f'x_{i}').value)
        results.append(fixed_to_float(val))
    return results

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bandwidth_allocation(dut):
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases scaled for 16-bit inputs
    test_cases = [
        # n=3, t=10, all fair share = 3.333333
        {
            'n': 3,
            't': 10,
            'a': [0, 0, 0],
            'b': [65535, 65535, 65535],  # ~1.0 in Q16.16
            'd': [1, 1, 1],
            'expected': [3.33333333, 3.33333333, 3.33333333]
        },
        # n=3, t=10, capped at 1, then 6, 3
        {
            'n': 3,
            't': 10,
            'a': [0, 2, 2],
            'b': [65535, 8, 8],  # 1.0, 0.122, 0.122 in Q16.16 (scaled)
            'd': [1000, 2, 1],
            'expected': [1.0, 6.0, 3.0]
        },
        # Simple case with tight bounds
        {
            'n': 2,
            't': 10,
            'a': [3, 2],
            'b': [7, 8],
            'd': [1, 1],
            'expected': [5.0, 5.0]
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"\n=== Test Case {tc_idx + 1} ===")
        cocotb.log.info(f"n={tc['n']}, t={tc['t']}")
        
        try:
            # Write inputs
            dut.n.value = tc['n']
            dut.t.value = clamp_to_width(tc['t'], 16)
            
            # Write species parameters
            await write_species_params(dut, tc['n'], tc['a'], tc['b'], tc['d'])
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            results = await read_allocation(dut, tc['n'])
            
            # Verify with tolerance
            for i in range(tc['n']):
                expected = tc['expected'][i]
                actual = results[i]
                
                # Calculate relative error
                denom = max(1.0, abs(expected))
                rel_err = abs(actual - expected) / denom
                
                cocotb.log.info(f"Species {i}: expected={expected:.8f}, actual={actual:.8f}, rel_err={rel_err:.2e}")
                
                if rel_err > 1e-6:
                    raise TestFailure(
                        f"Species {i}: relative error {rel_err:.2e} > 1e-6"
                    )
            
            passed += 1
            cocotb.log.info(f"Test {tc_idx + 1}: PASSED")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {tc_idx + 1}: FAILED - {e}")
            failed += 1
            
    # Final result
    if failed > 0:
        raise TestFailure(f"\n{failed} test(s) failed, {passed} passed")
    cocotb.log.info(f"\nAll {passed} tests passed!")
