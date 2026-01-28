import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS (Included for completeness, not used)
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
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
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# EXPECTED RESULT CALCULATION
# ============================================================================

def is_prime(num):
    """Check if a number is prime (for small numbers)."""
    if num < 2:
        return False
    if num == 2:
        return True
    if num % 2 == 0:
        return False
    for i in range(3, int(num**0.5) + 1, 2):
        if num % i == 0:
            return False
    return True

def is_product_of_two_primes(x):
    """Check if x can be expressed as product of two primes (p and q)."""
    if x < 4:
        return False
    limit = int(x**0.5) + 1
    for p in range(2, limit):
        if x % p == 0:
            q = x // p
            if is_prime(p) and is_prime(q):
                return True
    return False

def compute_expected(k, n):
    """Compute expected number of wonderful lawns for given k and n."""
    count = 0
    if n >= 1:
        F = 42
        if is_product_of_two_primes(F):
            count += 1
        if n >= 2:
            F_prev = F
            F = 11 * k + 77
            if is_product_of_two_primes(F):
                count += 1
            if n >= 3:
                F_prev_prev = F_prev
                F_prev = F
                for i in range(3, n + 1):
                    F = 2 * F_prev - F_prev_prev + 10 * k
                    if is_product_of_two_primes(F):
                        count += 1
                    F_prev_prev = F_prev
                    F_prev = F
    return count

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_troublemakers(dut):
    """Test the troublemakers module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Test cases: (k, n, expected_result)
    test_cases = [
        (1, 5, 0),   # Example from problem
        (2, 8, 1),   # k=2, n=8 should have 1 wonderful lawn (527)
        (4, 2, 1),   # k=4, n=2 -> 121
        (6, 6, 2),   # k=6, n=6 -> 143 and 1147
        (6, 2, 1),   # k=6, n=2 -> 143
        (8, 6, 1),   # k=8, n=6 -> 1457
    ]
    
    passed = 0
    failed = 0
    
    for i, (k, n, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: k={k}, n={n}, expected={expected}")
        
        try:
            # Set inputs
            dut.k.value = k
            dut.n.value = n
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")