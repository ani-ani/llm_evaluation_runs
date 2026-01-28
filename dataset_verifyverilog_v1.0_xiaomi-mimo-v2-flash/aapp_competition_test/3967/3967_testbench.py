import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 32
ARRAY_SIZE = 100
CLK_NS = 10
MAX_CYCLES = 100000

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Expected calculation (Python reference)
def expected_result(n, k, a):
    max_a = max(a)
    high = max_a + k + 1  # exclusive upper bound
    low = 1
    while low < high - 1:
        mid = (low + high) // 2
        # Calculate waste for d = mid
        waste = 0
        for val in a:
            waste += (mid - 1) - ((val - 1) % mid)
        if waste <= k:
            low = mid
        else:
            high = mid
    return low

async def write_array(dut, name, vals, width):
    """Write values to individual array elements"""
    for i, v in enumerate(vals):
        elem = getattr(dut, f"{name}_{i}", None)
        if elem is not None:
            elem.value = clamp_to_width(v, width)
        else:
            # Try indexed access
            try:
                dut.__getattr__(name)[i].value = clamp_to_width(v, width)
            except:
                pass

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bamboo_cut(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just wait for evaluation
        await Timer(100, units='ns')
    
    # Test cases: (n, k, [a_list], expected_d, description)
    test_cases = [
        (3, 4, [1, 3, 5], 3, "Example 1"),
        (3, 40, [10, 30, 50], 32, "Example 2"),
        (2, 948507270, [461613425, 139535653], 774828174, "Large k"),
        (1, 100000000000, [1000000000], 101000000000, "Single bamboo, large k"),
        (1, 100000000000, [1], 100000000001, "Min height, large k"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, k_val, a_vals, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n_val}, k={k_val})")
        
        try:
            # Write inputs
            if is_seq:
                # Write n (8-bit)
                if has_signal(dut, 'n'):
                    dut.n.value = n_val
                else:
                    # Check for individual ports or array
                    pass
                
                # Write k (64-bit)
                if has_signal(dut, 'k'):
                    dut.k.value = k_val
                else:
                    # Check for k_high/k_low or k_0..k_7
                    for bit in range(8):
                        if has_signal(dut, f'k_{bit}'):
                            getattr(dut, f'k_{bit}').value = (k_val >> (bit * 8)) & 0xFF
                
                # Write array a[0..n_val-1]
                for idx in range(min(n_val, ARRAY_SIZE)):
                    val = a_vals[idx]
                    # Try individual element ports
                    if has_signal(dut, f'a_{idx}'):
                        getattr(dut, f'a_{idx}').value = val
                    else:
                        # Try array access
                        try:
                            dut.a[idx].value = val
                        except:
                            pass
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if has_signal(dut, 'result'):
                    result = int(dut.result.value)
                else:
                    result = 0
                    for bit in range(32):
                        if has_signal(dut, f'result_{bit}'):
                            result |= (int(getattr(dut, f'result_{bit}').value) << bit)
            else:
                # Combinational: set inputs and wait
                if has_signal(dut, 'n'):
                    dut.n.value = n_val
                if has_signal(dut, 'k'):
                    dut.k.value = k_val
                for idx in range(min(n_val, ARRAY_SIZE)):
                    val = a_vals[idx]
                    if has_signal(dut, f'a_{idx}'):
                        getattr(dut, f'a_{idx}').value = val
                await Timer(100, units='ns')
                result = int(dut.result.value) if has_signal(dut, 'result') else 0
            
            # Verify result
            if not is_value_defined(result):
                raise TestFailure("Result undefined")
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")