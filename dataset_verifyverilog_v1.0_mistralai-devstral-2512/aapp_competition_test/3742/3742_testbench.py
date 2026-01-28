import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_garland(dut):
    """Test Garland Complexity Minimization Module"""
    
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic
        await Timer(100, units='ns')
    
    # Test cases: (n, arr_parity_list, odd_total, even_total, expected_complexity)
    # arr_parity: 1 for odd, 0 for even, 2 for zero (removed)
    test_cases = [
        # Simple case: n=5, arr=[0,5,0,2,3] -> 2
        (5, [2,1,2,0,1], 2, 3, 2),
        # Second example: n=7, arr=[1,0,0,5,0,0,2] -> 1
        (7, [1,2,2,1,2,2,0], 3, 4, 1),
        # Edge case: n=1, arr=[0] -> 0
        (1, [2], 1, 0, 0),
        # Fixed array: n=4, arr=[1,2,3,4] -> complexity?
        # 1(odd)-2(even):1, 2-3:1, 3-4:1 = 3
        # But test expects min, all fixed so complexity is fixed
        (4, [1,0,1,0], 2, 2, 3),
        # Mixed case: n=6, all zeros -> arrange optimally
        # Best: odd,odd,even,even,odd,even or similar
        # With 3 odd, 3 even: minimum complexity is 1
        (6, [2,2,2,2,2,2], 3, 3, 1),
        # More zeros: n=8, 4 odd, 4 even, all zeros
        # Can alternate: o,e,o,e,o,e,o,e = 7 edges
        # Or: o,o,e,e,o,o,e,e = 3 transitions between blocks
        # Minimum is 3
        (8, [2]*8, 4, 4, 3),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, arr_parity, odd_total, even_total, expected) in enumerate(test_cases):
        desc = f"Case {i+1}: n={n}, odd={odd_total}, even={even_total}, expected={expected}"
        cocotb.log.info(f"Test: {desc}")
        
        try:
            # Set inputs
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 7)
            
            # Set arr_parity bits
            if has_signal(dut, 'arr_parity'):
                # Pack into bit vector
                packed = 0
                for idx, val in enumerate(arr_parity):
                    # val: 2=zero (0 in our encoding), 0=even (0), 1=odd (1)
                    bit = 0 if val == 2 or val == 0 else 1
                    packed |= (bit << idx)
                dut.arr_parity.value = packed
            
            # Set individual arr_parity signals if they exist
            for idx in range(n):
                if has_signal(dut, f'arr_parity_{idx}'):
                    bit = 0 if arr_parity[idx] == 2 or arr_parity[idx] == 0 else 1
                    getattr(dut, f'arr_parity_{idx}').value = bit
            
            if has_signal(dut, 'odd_total'):
                dut.odd_total.value = clamp_to_width(odd_total, 6)
            if has_signal(dut, 'even_total'):
                dut.even_total.value = clamp_to_width(even_total, 6)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
                result = int(dut.result.value) if is_value_defined(dut.result.value) else 0
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASSED: result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAILED: {e}")
            failed += 1
    
    # Additional random tests for n=10
    for _ in range(3):
        n = 10
        arr_parity = []
        for _ in range(n):
            r = random.random()
            if r < 0.3:
                arr_parity.append(2)  # zero/removed
            elif r < 0.65:
                arr_parity.append(0)  # even
            else:
                arr_parity.append(1)  # odd
        
        # Count fixed odds/evens
        fixed_odd = sum(1 for x in arr_parity if x == 1)
        fixed_even = sum(0 for x in arr_parity if x == 0)
        zeros = sum(1 for x in arr_parity if x == 2)
        
        # Random totals for test (within reasonable bounds)
        odd_total = clamp_to_width(random.randint(fixed_odd, fixed_odd + zeros), 6)
        even_total = clamp_to_width(n - odd_total, 6)
        
        # We don't know expected answer, but module should complete
        desc = f"Random case: n={n}, odd_total={odd_total}, even_total={even_total}"
        cocotb.log.info(f"Test: {desc}")
        
        try:
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 7)
            
            if has_signal(dut, 'arr_parity'):
                packed = 0
                for idx, val in enumerate(arr_parity):
                    bit = 0 if val == 2 or val == 0 else 1
                    packed |= (bit << idx)
                dut.arr_parity.value = packed
            
            for idx in range(n):
                if has_signal(dut, f'arr_parity_{idx}'):
                    bit = 0 if arr_parity[idx] == 2 or arr_parity[idx] == 0 else 1
                    getattr(dut, f'arr_parity_{idx}').value = bit
            
            if has_signal(dut, 'odd_total'):
                dut.odd_total.value = clamp_to_width(odd_total, 6)
            if has_signal(dut, 'even_total'):
                dut.even_total.value = clamp_to_width(even_total, 6)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            else:
                await Timer(100, units='ns')
                result = int(dut.result.value) if is_value_defined(dut.result.value) else 0
            
            # Sanity check: result should be between 0 and n-1
            if result < 0 or result > n:
                raise TestFailure(f"Result {result} out of valid range [0, {n}]")
            
            cocotb.log.info(f"  PASSED: result={result}")
            passed += 1
            
        except Exception as e:
            cocotb.log.error(f"  FAILED: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{passed}")
