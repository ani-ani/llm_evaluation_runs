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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def float_to_fixed(f, frac=8):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=8):
    return v / (1 << frac)

DATA_WIDTH, CLK_NS, MAX_CYCLES = 16, 10, 1000

def compute_expected(X, max_digits=8):
    """Compute expected solutions for testing"""
    results = []
    X_val = float(X)
    epsilon = 0.01  # Tolerance for float comparison
    
    # For each digit length
    for d in range(1, max_digits + 1):
        start = 10**(d-1)
        end = 10**d
        for n in range(start, end):
            # Check if N has exactly d digits
            if len(str(n)) != d:
                continue
            # Compute rotated number
            s = str(n)
            rotated_str = s[1:] + s[0]
            rotated = int(rotated_str)
            # Check condition
            if abs(n * X_val - rotated) < epsilon:
                results.append(n)
    return sorted(results)

@cocotb.test(timeout_time=10, timeout_unit='s')
async def test_module(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        (2.6, "2.6", "Multiply by 2.6 with digit rotation"),
        (3.1416, "3.1416", "No solution expected"),
        (1.5, "1.5", "Other multiplier")
    ]
    
    for i, (X_val, X_str, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Convert X to fixed-point Q8.8
        x_fixed = float_to_fixed(X_val, 8)
        x_fixed = clamp_to_width(x_fixed, 16)
        
        # Set inputs
        if has_signal(dut, 'x_in'):
            dut.x_in.value = x_fixed
        if has_signal(dut, 'start_num'):
            dut.start_num.value = 0
        
        # Start search
        if is_seq and has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            await Timer(100, units='ns')
        
        # Wait for done
        done = False
        results = []
        timeout = 0
        
        while not done and timeout < 10000:
            await RisingEdge(dut.clk) if is_seq else Timer(10, units='ns')
            timeout += 1
            
            # Check for found number
            if has_signal(dut, 'found_valid') and is_value_defined(dut.found_valid.value):
                if int(dut.found_valid.value) == 1:
                    if has_signal(dut, 'found_num') and is_value_defined(dut.found_num.value):
                        num = int(dut.found_num.value)
                        results.append(num)
                        cocotb.log.info(f"Found: {num}")
            
            # Check for done
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) == 1:
                    done = True
        
        # Verify results
        expected = compute_expected(X_val)
        cocotb.log.info(f"Expected {len(expected)} solutions: {expected}")
        cocotb.log.info(f"Found {len(results)} solutions: {results}")
        
        if not expected and not results:
            # Both empty - OK if done signal present
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) != 1:
                    raise TestFailure("Done signal not set")
                cocotb.log.info("Test passed: No solutions as expected")
            else:
                cocotb.log.warning("Done signal not checked")
        else:
            # Check counts match
            if has_signal(dut, 'solution_count') and is_value_defined(dut.solution_count.value):
                count = int(dut.solution_count.value)
                if count != len(expected):
                    raise TestFailure(f"Solution count mismatch: expected {len(expected)}, got {count}")
            
            # Check results match (order may differ due to buffer, so compare sets)
            if set(results) != set(expected):
                raise TestFailure(f"Results mismatch: expected {expected}, got {results}")
            
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) != 1:
                    raise TestFailure("Done signal not set after completion")
        
        cocotb.log.info(f"Test {i+1} passed")
        
        # Reset for next test
        if is_seq and i < len(test_cases) - 1:
            await reset_dut(dut)
    
    cocotb.log.info("All tests passed!")
