import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# --- Helper Functions (MANDATORY) ---
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
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_reference(a_list, k):
    """Compute the Python reference result"""
    g = k
    for val in a_list:
        val_mod = val % k
        g = math.gcd(g, val_mod)
    count = k // g
    d_values = sorted([i * g for i in range(count)])
    return d_values

# --- Constants ---
DATA_WIDTH = 16  # For a_i
K_WIDTH = 8      # For k_in and result_d
N_MAX = 16       # Max denominations
CLK_NS = 10
MAX_CYCLES = 1000

# --- Testbench ---
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_natasha_tax(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases (scaled down)
    test_cases = [
        # (denominations, base_k, expected_d_list)
        ([12, 20], 8, [0, 4]),
        ([10, 20, 30], 10, [0]),
        ([20, 16, 4, 16, 2], 10, [0, 2, 4, 6, 8]),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 12, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]),
        ([2, 4, 6, 8], 12, [0, 2, 4, 6, 8, 10]),
        ([5, 15], 30, [0, 5, 10, 15, 20, 25]),
    ]
    
    passed = 0
    failed = 0
    
    for tc_idx, (denoms, base_k, expected_d) in enumerate(test_cases):
        cocotb.log.info(f"\nTest Case {tc_idx + 1}: Denoms={denoms}, K={base_k}")
        
        # Prepare inputs
        n_val = len(denoms)
        if n_val > N_MAX:
            cocotb.log.error(f"Test case has {n_val} denominations, max allowed is {N_MAX}. Skipping.")
            continue
            
        if base_k >= (1 << K_WIDTH):
            cocotb.log.error(f"Base k={base_k} exceeds {K_WIDTH}-bit limit ({1<<K_WIDTH}). Skipping.")
            continue
            
        # 1. Write inputs
        # n
        dut.n.value = n_val
        # k_in
        dut.k_in.value = base_k
        # a array (denominations)
        # Handle either packed array or individual signals
        # Try packed first (a[0:15])
        if has_signal(dut, 'a'):
            # Check if it's an array or vector
            try:
                _ = dut.a[0]
                # It's an array/vector
                for i in range(N_MAX):
                    val = denoms[i] if i < n_val else 0
                    dut.a[i].value = clamp_to_width(val % base_k, DATA_WIDTH)
            except (AttributeError, TypeError):
                # It's likely a single vector port, handle as packed
                # Since the spec says array, we'll assume individual elements or vector array access
                # If it's a single vector 'a', we need to pack it. But Verilog arrays are usually elements.
                # Let's assume the DUT has a[0]...a[15] or a vector array.
                pass
        else:
            # Check for individual ports a_0, a_1...
            has_individual = False
            for i in range(N_MAX):
                if has_signal(dut, f'a_{i}'):
                    val = denoms[i] if i < n_val else 0
                    getattr(dut, f'a_{i}').value = clamp_to_width(val % base_k, DATA_WIDTH)
                    has_individual = True
            if not has_individual:
                raise TestFailure("Could not access input array 'a' or individual ports 'a_i'")

        # 2. Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 3. Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"Test {tc_idx+1} failed: {e}")
            failed += 1
            continue
            
        # 4. Read results
        # Read result_count
        if not is_value_defined(dut.result_count.value):
            cocotb.log.error(f"Test {tc_idx+1}: result_count undefined")
            failed += 1
            continue
            
        result_count = int(dut.result_count.value)
        
        # Read result_d array
        result_d = []
        if has_signal(dut, 'result_d'):
            try:
                _ = dut.result_d[0]
                for i in range(N_MAX):
                    if is_value_defined(dut.result_d[i].value):
                        result_d.append(int(dut.result_d[i].value))
                    else:
                        result_d.append(0) # Default to 0 if undefined
            except (AttributeError, TypeError):
                # Single vector, unpack it
                # We assume packed format if it's a single signal, but spec implies array
                pass
        else:
            # Individual ports
            valid_found = False
            for i in range(N_MAX):
                port_name = f'result_d_{i}'
                if has_signal(dut, port_name):
                    val = getattr(dut, port_name).value
                    result_d.append(safe_int(val, 0))
                    valid_found = True
                else:
                    result_d.append(0) 
            if not valid_found:
                raise TestFailure("Could not access output array 'result_d'")

        # 5. Verify
        # Expected length
        if result_count != len(expected_d):
            cocotb.log.error(f"Test {tc_idx+1}: Expected count {len(expected_d)}, got {result_count}")
            cocotb.log.error(f"Result D values: {result_d[:result_count]}")
            failed += 1
            continue
            
        # Expected values (first 'result_count' values must match)
        actual_vals = result_d[:result_count]
        if actual_vals != expected_d:
            cocotb.log.error(f"Test {tc_idx+1}: Expected values {expected_d}, got {actual_vals}")
            failed += 1
            continue
            
        cocotb.log.info(f"Test {tc_idx+1} PASSED. Result count: {result_count}, Values: {actual_vals}")
        passed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed.")
