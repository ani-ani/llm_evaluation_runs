import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Scale limits for the testbench
MAX_N = 64
COORD_WIDTH = 16
IDX_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_value(v, bits):
    """Pack integer into bitstring for assignment"""
    from ctypes import c_uint
    return c_uint(clamp_to_width(v, bits)).value

# Test case data structure
test_cases = [
    {
        'desc': 'Sample 1: Valid matching 2-1',
        'tl': [(4,7), (9,8)],  # (r,c)
        'br': [(14,17), (19,18)],
        'expected_syntax_error': 0,
        'expected_match': [1, 0]  # TL0->BR1, TL1->BR0 (0-indexed)
    },
    {
        'desc': 'Sample 2: Valid matching 1-2',
        'tl': [(4,7), (14,17)],
        'br': [(9,8), (19,18)],
        'expected_syntax_error': 0,
        'expected_match': [0, 1]  # TL0->BR0, TL1->BR1
    },
    {
        'desc': 'Sample 3: Invalid nesting',
        'tl': [(4,8), (9,7)],
        'br': [(14,18), (19,17)],
        'expected_syntax_error': 1,
        'expected_match': None
    },
    {
        'desc': 'Sample 4: Single invalid rectangle',
        'tl': [(1,1), (4,8), (8,4)],
        'br': [(10,6), (6,10), (10,10)],
        'expected_syntax_error': 1,
        'expected_match': None
    }
]

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_visual_python_parser(dut):
    """Test the Visual Python++ parser for rectangle nesting"""
    
    # Setup clock and reset
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for tc_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"\nTest {tc_idx+1}: {tc['desc']}")
        
        try:
            # Prepare inputs
            n = len(tc['tl'])
            if n > MAX_N:
                cocotb.log.warning(f"Skipping test with n={n} > MAX_N={MAX_N}")
                continue
            
            # Assign top-left coordinates
            for i in range(n):
                # Check if individual TL ports exist
                if has_signal(dut, f'tl_r_i[{i}]'):
                    dut._handle.tl_r_i[i].value = clamp_to_width(tc['tl'][i][0], COORD_WIDTH)
                    dut._handle.tl_c_i[i].value = clamp_to_width(tc['tl'][i][1], COORD_WIDTH)
                elif hasattr(dut.tl_r_i, '__setitem__'):
                    dut.tl_r_i[i].value = clamp_to_width(tc['tl'][i][0], COORD_WIDTH)
                    dut.tl_c_i[i].value = clamp_to_width(tc['tl'][i][1], COORD_WIDTH)
            
            # Assign bottom-right coordinates
            for i in range(n):
                if hasattr(dut.br_r_i, '__setitem__'):
                    dut.br_r_i[i].value = clamp_to_width(tc['br'][i][0], COORD_WIDTH)
                    dut.br_c_i[i].value = clamp_to_width(tc['br'][i][1], COORD_WIDTH)
            
            # For unused ports, set to 0
            for i in range(n, MAX_N):
                if hasattr(dut.tl_r_i, '__setitem__'):
                    dut.tl_r_i[i].value = 0
                    dut.tl_c_i[i].value = 0
                    dut.br_r_i[i].value = 0
                    dut.br_c_i[i].value = 0
            
            if is_seq:
                # Start processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check syntax_error
            if not is_value_defined(dut.syntax_error.value):
                raise TestFailure("syntax_error signal is undefined")
            
            actual_syntax_error = int(dut.syntax_error.value)
            expected_syntax_error = tc['expected_syntax_error']
            
            if actual_syntax_error != expected_syntax_error:
                raise TestFailure(
                    f"syntax_error mismatch: expected {expected_syntax_error}, got {actual_syntax_error}"
                )
            
            # If valid, check matching
            if actual_syntax_error == 0:
                if not is_value_defined(dut.result_valid.value):
                    raise TestFailure("result_valid is undefined")
                
                actual_result_valid = int(dut.result_valid.value)
                if actual_result_valid != 1:
                    raise TestFailure(f"result_valid should be 1, got {actual_result_valid}")
                
                # Read match_index array
                actual_match = []
                for i in range(n):
                    if hasattr(dut.match_index, '__getitem__'):
                        val = int(dut.match_index[i].value)
                        actual_match.append(val)
                    elif has_signal(dut, f'match_index_{i}'):
                        val = int(getattr(dut, f'match_index_{i}').value)
                        actual_match.append(val)
                    else:
                        raise TestFailure(f"Cannot access match_index[{i}]")
                
                # Check if matching is valid
                if len(actual_match) != n:
                    raise TestFailure(f"Expected {n} matches, got {len(actual_match)}")
                
                # Verify it's a permutation
                sorted_actual = sorted(actual_match)
                if sorted_actual != list(range(n)):
                    raise TestFailure(f"match_index is not a valid permutation. Got {actual_match}")
                
                # Check if matches the expected (if provided)
                if tc['expected_match'] is not None:
                    if actual_match != tc['expected_match']:
                        # Log warning since any valid matching is acceptable
                        cocotb.log.info(f"Got matching {actual_match}, expected {tc['expected_match']} (any valid matching is acceptable)")
                
                # Additional validation: check rectangles are valid
                for i in range(n):
                    tl_r = tc['tl'][i][0]
                    tl_c = tc['tl'][i][1]
                    br_idx = actual_match[i]
                    br_r = tc['br'][br_idx][0]
                    br_c = tc['br'][br_idx][1]
                    
                    if tl_r > br_r or tl_c > br_c:
                        raise TestFailure(
                            f"Invalid rectangle: TL({tl_r},{tl_c}) -> BR({br_r},{br_c})"
                        )
            
            cocotb.log.info(f"PASS: Test {tc_idx+1}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {tc_idx+1} - {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")
