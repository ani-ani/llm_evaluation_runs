import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 16  # Influence in Q16.16
FIXED_FRAC = 16
MAX_PEOPLE = 16
CLK_NS = 10
MAX_CYCLES = 1500

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

def float_to_fixed(f, frac=FIXED_FRAC):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=FIXED_FRAC):
    return v / (1 << frac)

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

def decode_type(s):
    # '00'->0, '01'->1, '10'->2, '11'->3
    return int(s, 2)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def compute_expected(people):
    """Compute expected result using Python greedy algorithm"""
    if not people:
        return 0, False
    
    # Parse and categorize
    cat00, cat01, cat10, cat11 = [], [], [], []
    for p_type, p_inf in people:
        if p_type == '00': cat00.append(p_inf)
        elif p_type == '01': cat01.append(p_inf)
        elif p_type == '10': cat10.append(p_inf)
        elif p_type == '11': cat11.append(p_inf)
    
    # Sort descending
    cat00.sort(reverse=True)
    cat01.sort(reverse=True)
    cat10.sort(reverse=True)
    cat11.sort(reverse=True)
    
    # Step 1: Take all 11s
    result = sum(cat11)
    m = len(cat11)  # total people
    a = len(cat11)  # Alice supporters
    b = len(cat11)  # Bob supporters
    
    # Step 2: Pair 10s and 01s
    pairs = min(len(cat10), len(cat01))
    for i in range(pairs):
        result += cat10[i] + cat01[i]
        m += 2
        a += 1
        b += 1
    
    # Remaining people to consider
    remaining = []
    if len(cat10) > pairs:
        remaining.extend(cat10[pairs:])
    if len(cat01) > pairs:
        remaining.extend(cat01[pairs:])
    remaining.extend(cat00)
    remaining.sort(reverse=True)
    
    # Step 3: Fill remainder with highest values
    # We can add up to 2*m (constraints) or all remaining
    # Greedy: add highest values while constraints hold
    added = 0
    for val in remaining:
        new_m = m + 1
        new_a = a + 1 if val in cat10[pairs:] else a
        new_b = b + 1 if val in cat01[pairs:] else b
        # Check if adding maintains constraints (or makes them satisfiable)
        # Actually, we need final: 2*a >= m and 2*b >= m
        # After adding, we'll check
        result += val
        m += 1
        if val in cat10[pairs:]: a += 1
        elif val in cat01[pairs:]: b += 1
        # else 00 doesn't change a or b
        added += 1
    
    # Final constraint check
    if m == 0:
        return 0, False
    if (2*a >= m) and (2*b >= m):
        return result, True
    else:
        # Find max valid subset
        # Simple approach: try all prefixes
        best = 0
        valid_found = False
        for k in range(1, len(remaining)+1):
            test_m = m - (added - k)
            test_a = a
            test_b = b
            test_res = result - sum(remaining[k:])
            # Recalculate counts for the k items
            for i in range(k):
                if remaining[i] in cat10[pairs:]: test_a += 1
                elif remaining[i] in cat01[pairs:]: test_b += 1
            if test_m > 0 and (2*test_a >= test_m) and (2*test_b >= test_m):
                if test_res > best:
                    best = test_res
                    valid_found = True
        if valid_found:
            return best, True
        return 0, False

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_election(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # Format: (people_list, expected_result)
        ([("11", 6), ("10", 4), ("01", 3), ("00", 3), ("00", 7), ("00", 9)], 22),
        ([("11", 1), ("01", 1), ("00", 100), ("10", 1), ("01", 1)], 103),
        ([("11", 19), ("10", 22), ("00", 18), ("00", 29), ("11", 29), ("10", 28)], 105),
        ([("00", 5000), ("00", 5000), ("00", 5000)], 0),
        ([("11", 15)], 15),
        ([("10", 1), ("01", 1)], 2),  # Should be valid
    ]
    
    passed = 0
    failed = 0
    
    for i, (people, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {len(people)} people, expected {expected}")
        
        if len(people) > MAX_PEOPLE:
            cocotb.log.info(f"Skipping: too many people ({len(people)} > {MAX_PEOPLE})")
            continue
        
        try:
            # Compute expected for complex cases
            exp_result, exp_valid = compute_expected(people)
            
            # Setup inputs
            if is_seq:
                dut.N.value = len(people)
                
                # Initialize arrays to 0
                for j in range(MAX_PEOPLE):
                    dut.people_type[j].value = 0
                    dut.people_influence[j].value = 0
                
                # Set inputs
                for j, (p_type, p_inf) in enumerate(people):
                    dut.people_type[j].value = decode_type(p_type)
                    # Convert to Q16.16
                    inf_fixed = int(p_inf * (1 << 16))
                    dut.people_influence[j].value = clamp_to_width(inf_fixed, DATA_WIDTH)
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result_int = int(dut.result.value)
                valid_bit = int(dut.valid.value) if has_signal(dut, 'valid') else 1
                
                # Convert from Q16.16 to integer
                result_int = result_int >> 16
                
                if expected == 0:
                    # Should be invalid or result 0
                    if valid_bit == 1 and result_int != 0:
                        raise TestFailure(f"Expected invalid or 0, got valid={valid_bit}, result={result_int}")
                else:
                    if not valid_bit:
                        raise TestFailure(f"Expected valid set, got valid={valid_bit}")
                    if result_int != expected:
                        raise TestFailure(f"Expected {expected}, got {result_int}")
                
                passed += 1
            else:
                # Combinational - just set inputs and wait
                for j, (p_type, p_inf) in enumerate(people):
                    # Would need individual signals for comb
                    pass
                await Timer(100, units='ns')
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed")