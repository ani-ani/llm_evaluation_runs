import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

def sort_ascending(arr):
    return sorted(arr)

def sort_descending(arr):
    return sorted(arr, reverse=True)

def calculate_expected(n_cards, jiro_pos, jiro_str, ciel_str):
    # Helper to calculate expected result in Python
    # 1. Strategy 1: Destroy all
    def_str = [j_str for p, j_str in zip(jiro_pos, jiro_str) if p == 0]
    atk_str = [j_str for p, j_str in zip(jiro_pos, jiro_str) if p == 1]
    c_str = list(ciel_str)
    
    def_str.sort()
    atk_str.sort()
    c_str.sort()
    
    s1_possible = True
    s1_damage = 0
    c_used = [False] * len(c_str)
    
    # Match Def
    for d_val in def_str:
        found = False
        for i in range(len(c_str)):
            if not c_used[i] and c_str[i] > d_val:
                c_used[i] = True
                found = True
                break
        if not found:
            s1_possible = False
            break
            
    # Match Atk
    if s1_possible:
        for a_val in atk_str:
            found = False
            for i in range(len(c_str)):
                if not c_used[i] and c_str[i] >= a_val:
                    c_used[i] = True
                    s1_damage += (c_str[i] - a_val)
                    found = True
                    break
            if not found:
                s1_possible = False
                break
        
        # Direct Attack with leftovers
        if s1_possible:
            for i in range(len(c_str)):
                if not c_used[i]:
                    s1_damage += c_str[i]
    else:
        s1_damage = 0
        
    # 2. Strategy 2: Attack only Atk cards
    atk_str_2 = sorted(atk_str)
    c_str_2 = sorted(ciel_str, reverse=True)
    s2_damage = 0
    atk_idx = 0
    for c_val in c_str_2:
        if atk_idx < len(atk_str_2) and c_val >= atk_str_2[atk_idx]:
            s2_damage += (c_val - atk_str_2[atk_idx])
            atk_idx += 1
            
    return max(s1_damage, s2_damage)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_card_battle(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test Cases (Scaled down for HDL limits: n,m <= 16)
    # Format: (jiro_pos_list, jiro_str_list, ciel_str_list, expected_result)
    # pos: 1=ATK, 0=DEF
    test_cases = [
        # Example 1 (Scaled)
        ([1, 0], [2000, 1700], [2500, 2500, 2500], 3000),
        # Example 2 (Scaled)
        ([1, 1, 1], [10, 100, 1000], [1, 11, 101, 1001], 992),
        # Example 3 (Scaled)
        ([0, 1], [0, 0], [0, 0, 1, 1], 1),
        # Edge case: Strategy 2 better
        ([1, 1], [100, 200], [150, 250], 100), # 150-100=50, 250-200=50. Total 100. Strategy 1 fails if def cards present, but here no def.
        # Edge case: Impossible match
        ([0], [10], [5], 0),
        # Mixed large
        ([1, 1, 0, 0], [10, 100, 200, 300], [50, 150, 250, 350], 350),
    ]
    
    passed = 0
    failed = 0
    
    for i, (j_pos, j_str, c_str, expected) in enumerate(test_cases):
        n = len(j_pos)
        m = len(c_str)
        
        # Pad inputs to max 16
        j_pos_padded = j_pos + [0] * (16 - n)
        j_str_padded = j_str + [0] * (16 - n)
        c_str_padded = c_str + [0] * (16 - m)
        
        cocotb.log.info(f"Test {i+1}: n={n}, m={m}, Expected={expected}")
        
        try:
            # Write Inputs
            # Assuming jiro_pos is a 16-bit signal
            dut.jiro_pos.value = 0
            for bit_idx, val in enumerate(j_pos_padded):
                if val:
                    dut.jiro_pos.value |= (1 << bit_idx)
            
            # Write Jiro Str (Assuming array of signals or packed array)
            # Since Python lists are easier, we iterate if possible or access by name
            # Access pattern depends on Verilog definition. Let's assume flat names or array index.
            # Assuming dut.jiro_str[i] is a signal
            for idx in range(16):
                getattr(dut, f'jiro_str_{idx}').value = j_str_padded[idx]
            
            # Write Ciel Str
            for idx in range(16):
                getattr(dut, f'ciel_str_{idx}').value = c_str_padded[idx]
                
            # Write Counts
            dut.n.value = n
            dut.m.value = m
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=2000)
            
            # Read Result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
            
            # Reset for next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")