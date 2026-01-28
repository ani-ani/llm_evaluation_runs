import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit='ms')
async def test_find_permutations(dut):
    """Test the find_permutations module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, a_list, expected_pi, expected_sigma, description)
    test_cases = [
        (5, [3, 2, 3, 1, 1], [1, 4, 3, 5, 2], [2, 3, 5, 1, 4], 'Sample 1'),
        (4, [3, 1, 1, 4], None, None, 'Impossible'),
        (2, [1, 2], [1, 2], [2, 1], 'Small n=2'),
        (3, [2, 3, 3], [1, 2, 3], [1, 1, 1], 'n=3 possible?'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, a_list, exp_pi, exp_sigma, description) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: {description}')
        
        try:
            # Write n
            if has_signal(dut, 'n'):
                dut.n.value = n
            else:
                raise TestFailure("Signal 'n' not found")
            
            # Write a array (up to 8 elements)
            for j in range(8):
                if j < n:
                    a_val = a_list[j]
                else:
                    a_val = 0  # don't care
                port_name = f'a_{j}'
                if has_signal(dut, port_name):
                    setattr(dut, port_name).value = a_val
                else:
                    raise TestFailure(f"Signal 'a_{j}' not found")
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check impossible flag
            impossible = int(dut.impossible.value) if is_value_defined(dut.impossible.value) else 1
            if exp_pi is None:
                # Expect impossible
                if impossible != 1:
                    raise TestFailure(f'Expected impossible, but got solution')
                else:
                    cocotb.log.info('  PASS: correctly impossible')
                    passed += 1
            else:
                # Expect solution
                if impossible == 1:
                    raise TestFailure(f'Expected solution, but got impossible')
                # Read pi and sigma
                pi_vals = []
                sigma_vals = []
                for j in range(8):
                    if j < n:
                        pi_port = f'pi_{j}'
                        sigma_port = f'sigma_{j}'
                        if has_signal(dut, pi_port):
                            pi_vals.append(int(getattr(dut, pi_port).value))
                        else:
                            pi_vals.append(0)
                        if has_signal(dut, sigma_port):
                            sigma_vals.append(int(getattr(dut, sigma_port).value))
                        else:
                            sigma_vals.append(0)
                    else:
                        # Ignore values for j >= n
                        pass
                
                # Check that pi and sigma are permutations of 1..n
                if sorted(pi_vals[:n]) != list(range(1, n+1)):
                    raise TestFailure(f'pi is not a permutation: {pi_vals[:n]}')
                if sorted(sigma_vals[:n]) != list(range(1, n+1)):
                    raise TestFailure(f'sigma is not a permutation: {sigma_vals[:n]}')
                
                # Check the condition: (pi_i + sigma_i) mod n == a_i
                for idx in range(n):
                    pi_val = pi_vals[idx]
                    sigma_val = sigma_vals[idx]
                    a_val = a_list[idx]
                    sum_mod = (pi_val + sigma_val) % n
                    if sum_mod == 0:
                        sum_mod = n  # because problem uses 1..n
                    if sum_mod != a_val:
                        raise TestFailure(f'At index {idx}: pi={pi_val}, sigma={sigma_val}, sum mod {n} = {sum_mod}, expected {a_val}')
                
                cocotb.log.info(f'  PASS: pi={pi_vals[:n]}, sigma={sigma_vals[:n]}')
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f'  FAIL: {e}')
            failed += 1
    
    # Summary
    cocotb.log.info(f'{"="*50}')
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')
