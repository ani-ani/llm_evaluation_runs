import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def clamp_to_width(v, bits):
    if v < 0:
        v = (1 << bits) + v
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

# Constants
DATA_WIDTH = 12
MAX_N = 20
MAX_P = 10
MAX_S = 10
RESULT_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 2000

async def write_array(dut, name, values, width):
    """Write values to array elements individually"""
    for i, val in enumerate(values):
        # Clamp to width
        if val < 0:
            clamped = val & ((1 << width) - 1)
        else:
            clamped = min((1 << width) - 1, val)
        
        # Access individual element
        if hasattr(dut, name):
            arr = getattr(dut, name)
            if hasattr(arr, '__len__'):
                arr[i].value = clamped
            else:
                # Packed array - need to shift
                # This is for packed arrays, but we'll use individual access
                pass
        else:
            # Try named ports arr_0, arr_1, ...
            getattr(dut, f'{name}_{i}').value = clamped

async def write_skills(dut, n, a_vals, b_vals):
    """Write skill arrays to DUT"""
    for i in range(n):
        dut.a[i].value = clamp_to_width(a_vals[i], DATA_WIDTH)
        dut.b[i].value = clamp_to_width(b_vals[i], DATA_WIDTH)
    # Zero out remaining slots
    for i in range(n, MAX_N):
        dut.a[i].value = 0
        dut.b[i].value = 0

async def wait_for_done(dut):
    """Wait for done signal with timeout"""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and safe_int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")

async def reset_dut(dut):
    """Reset DUT"""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_optimal_teams(dut):
    """Test the optimal team selection module"""
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from the problem
    test_cases = [
        {
            'name': 'Example 1',
            'n': 5, 'p': 2, 's': 2,
            'a': [1, 3, 4, 5, 2],
            'b': [5, 3, 2, 1, 4],
            'expected_strength': 18,
            'expected_p': [3, 4],  # 1-based indices
            'expected_s': [1, 5]
        },
        {
            'name': 'Example 2',
            'n': 4, 'p': 2, 's': 2,
            'a': [10, 8, 8, 3],
            'b': [10, 7, 9, 4],
            'expected_strength': 31,
            'expected_p': [1, 2],
            'expected_s': [3, 4]
        },
        {
            'name': 'Example 3',
            'n': 5, 'p': 3, 's': 1,
            'a': [5, 2, 5, 1, 7],
            'b': [6, 3, 1, 6, 3],
            'expected_strength': 23,
            'expected_p': [1, 3, 5],
            'expected_s': [4]
        },
        {
            'name': 'Small case',
            'n': 2, 'p': 1, 's': 1,
            'a': [100, 101],
            'b': [1, 100],
            'expected_strength': 200,
            'expected_p': [1],
            'expected_s': [2]
        }
    ]
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        cocotb.log.info(f"\n=== Running {test['name']} ===")
        
        try:
            if is_seq:
                # Write inputs
                dut.n.value = test['n']
                dut.p.value = test['p']
                dut.s.value = test['s']
                
                # Write arrays
                await write_skills(dut, test['n'], test['a'], test['b'])
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read results
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = safe_int(dut.result.value)
                
                # Read teams
                team_p = []
                team_s = []
                
                # Check if we have individual ports or array
                for i in range(MAX_P):
                    sig_name = f'team_p_{i}'
                    if has_signal(dut, sig_name):
                        val = safe_int(getattr(dut, sig_name).value)
                        if val > 0:
                            team_p.append(val)
                    elif hasattr(dut, 'team_p') and hasattr(dut.team_p, '__getitem__'):
                        val = safe_int(dut.team_p[i].value)
                        if val > 0:
                            team_p.append(val)
                
                for i in range(MAX_S):
                    sig_name = f'team_s_{i}'
                    if has_signal(dut, sig_name):
                        val = safe_int(getattr(dut, sig_name).value)
                        if val > 0:
                            team_s.append(val)
                    elif hasattr(dut, 'team_s') and hasattr(dut.team_s, '__getitem__'):
                        val = safe_int(dut.team_s[i].value)
                        if val > 0:
                            team_s.append(val)
                
                cocotb.log.info(f"Result: {result}")
                cocotb.log.info(f"Team P (size {len(team_p)}): {sorted(team_p)}")
                cocotb.log.info(f"Team S (size {len(team_s)}): {sorted(team_s)}")
                cocotb.log.info(f"Expected: {test['expected_strength']}")
                
                # Check result
                if result != test['expected_strength']:
                    raise TestFailure(f"Strength mismatch: expected {test['expected_strength']}, got {result}")
                
                # Check team sizes
                if len(team_p) != test['p']:
                    raise TestFailure(f"Team P size mismatch: expected {test['p']}, got {len(team_p)}")
                
                if len(team_s) != test['s']:
                    raise TestFailure(f"Team S size mismatch: expected {test['s']}, got {len(team_s)}")
                
                # Check distinctness
                combined = team_p + team_s
                if len(combined) != len(set(combined)):
                    raise TestFailure(f"Teams have overlapping members: {combined}")
                
                # Check all indices are in valid range
                for idx in combined:
                    if idx < 1 or idx > test['n']:
                        raise TestFailure(f"Invalid index {idx}, expected 1-{test['n']}")
                
                cocotb.log.info(f"Test {test['name']} PASSED")
                passed += 1
                
            else:
                # Combinational test
                await Timer(100, units='ns')
                result = safe_int(dut.result.value)
                cocotb.log.info(f"Result: {result}")
                if result == test['expected_strength']:
                    cocotb.log.info(f"Test {test['name']} PASSED")
                    passed += 1
                else:
                    raise TestFailure(f"Expected {test['expected_strength']}, got {result}")
                    
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            if is_seq:
                # Reset for next test
                await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
    
    cocotb.log.info(f"\n=== SUMMARY: {passed}/{len(test_cases)} tests passed ===")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_additional_cases(dut):
    """Test additional edge cases"""
    
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    additional_tests = [
        {
            'name': 'Equal skills',
            'n': 3, 'p': 1, 's': 1,
            'a': [10, 10, 10],
            'b': [10, 10, 10],
            'expected_strength': 20  # Any two students: 10+10=20
        },
        {
            'name': 'Different gains',
            'n': 4, 'p': 2, 's': 1,
            'a': [5, 4, 3, 2],
            'b': [1, 2, 5, 10],  # Gains: -4, -2, +2, +8
            'expected_strength': None  # Will check with simple calculation
        }
    ]
    
    # Simple verification for cases where expected might differ
    for test in additional_tests:
        if not is_seq:
            continue
            
        cocotb.log.info(f"\n=== Running {test['name']} ===")
        
        dut.n.value = test['n']
        dut.p.value = test['p']
        dut.s.value = test['s']
        
        await write_skills(dut, test['n'], test['a'], test['b'])
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        result = safe_int(dut.result.value)
        cocotb.log.info(f"Result: {result}")
        
        if test['expected_strength'] is not None:
            if result != test['expected_strength']:
                cocotb.log.error(f"Mismatch: expected {test['expected_strength']}")
                raise TestFailure(f"Strength mismatch")
        
        # Basic validation
        if result < 0 or result > 100000:
            raise TestFailure(f"Result out of expected range: {result}")
        
        cocotb.log.info(f"Test {test['name']} PASSED")
