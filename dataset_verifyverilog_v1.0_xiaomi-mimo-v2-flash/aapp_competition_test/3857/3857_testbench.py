import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 500  # Allow 256 for sorting + processing

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

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

def solve_piles(strengths):
    """Compute minimal piles using greedy algorithm"""
    if not strengths:
        return 0
    sorted_strengths = sorted(strengths)
    piles = []
    for s in sorted_strengths:
        # Find first pile where height <= s
        found = False
        for i, h in enumerate(piles):
            if h <= s:
                piles[i] += 1
                found = True
                break
        if not found:
            piles.append(1)
    return len(piles)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_minimal_piles(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational module
        dut.rst_n.value = 1
        if has_signal(dut, 'start'):
            dut.start.value = 0
    
    # Test cases: (input_array, expected_output, description)
    test_cases = [
        ([0, 0, 10], 2, "Example 1: 3 boxes"),
        ([0, 1, 2, 3, 4], 1, "Example 2: 5 boxes, 1 pile"),
        ([0, 0, 0, 0], 4, "Example 3: all zero strength"),
        ([0, 1, 0, 2, 0, 1, 1, 2, 10], 3, "Example 4: 9 boxes"),
        ([], 0, "Empty array"),
        ([0], 1, "Single box"),
        ([0, 0], 2, "Two zero boxes"),
        ([1, 1, 1, 1, 1], 1, "All strength 1"),
        ([255, 255, 255], 1, "Max strength"),
        ([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 1, "16 boxes ascending"),
        ([15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0], 16, "16 boxes descending - each needs own pile"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Pad input to ARRAY_SIZE
            padded_inp = inp + [0] * (ARRAY_SIZE - len(inp))
            
            if is_seq:
                # Write array
                for idx, val in enumerate(padded_inp):
                    setattr(dut, f'arr_{idx}', clamp_to_width(val, DATA_WIDTH))
                
                # Write length (clamped to 4 bits)
                dut.len.value = len(inp) & 0xF
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                result = int(dut.result.value)
            else:
                # Combinational: write inputs directly
                for idx, val in enumerate(padded_inp):
                    setattr(dut, f'arr_{idx}', clamp_to_width(val, DATA_WIDTH))
                dut.len.value = len(inp) & 0xF
                
                # Wait for propagation
                await Timer(100, units='ns')
                result = int(dut.result.value)
            
            # Check result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} -> {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR Test {i+1}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_stress_random(dut):
    """Test with random inputs to verify robustness"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        dut.rst_n.value = 1
    
    import random
    random.seed(42)
    
    # Generate 20 random test cases
    for test_idx in range(20):
        n = random.randint(0, 16)
        inp = [random.randint(0, 100) for _ in range(n)]
        
        # Compute expected (reference Python)
        expected = solve_piles(inp)
        
        # Pad and write
        padded_inp = inp + [0] * (ARRAY_SIZE - len(inp))
        
        if is_seq:
            for idx, val in enumerate(padded_inp):
                setattr(dut, f'arr_{idx}', clamp_to_width(val, DATA_WIDTH))
            dut.len.value = n & 0xF
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            result = int(dut.result.value)
        else:
            for idx, val in enumerate(padded_inp):
                setattr(dut, f'arr_{idx}', clamp_to_width(val, DATA_WIDTH))
            dut.len.value = n & 0xF
            await Timer(100, units='ns')
            result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Random test {test_idx}: n={n}, inp={inp}, expected={expected}, got={result}")
        
        cocotb.log.info(f"Random test {test_idx}: n={n}, result={result}")
    
    cocotb.log.info("All random tests passed")
