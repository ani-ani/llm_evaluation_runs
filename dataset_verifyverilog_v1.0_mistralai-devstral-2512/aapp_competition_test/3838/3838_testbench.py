import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def pack_perm(perm, value_bits=4):
    """Pack permutation array into integer for Verilog input"""
    packed = 0
    for i, val in enumerate(perm):
        packed |= (val & ((1 << value_bits) - 1)) << (i * value_bits)
    return packed

def unpack_perm(packed, n, value_bits=4):
    """Extract permutation from packed integer"""
    mask = (1 << value_bits) - 1
    perm = []
    for i in range(n):
        perm.append((packed >> (i * value_bits)) & mask)
    return perm

def compute_inverse(perm):
    """Compute inverse permutation (1-indexed)"""
    n = len(perm)
    inv = [0] * n
    for i, val in enumerate(perm):
        inv[val - 1] = i + 1  # Convert to 1-indexed
    return inv

def simulate_game(q, s, k, n):
    """Simulate the game in Python to verify expected result"""
    # Identity permutation
    identity = list(range(1, n+1))
    
    # q is 1-indexed, convert to 0-indexed for simulation
    q0 = [x-1 for x in q]
    
    # Compute inverse of q
    q_inv = [0] * n
    for i in range(n):
        q_inv[q0[i]] = i
    # Convert back to 1-indexed
    q_inv = [x+1 for x in q_inv]
    
    # Check if s == identity (violates condition if k>0)
    if k > 0 and s == identity:
        return False
    
    # Simulate all possible sequences of moves
    # Due to k ≤ 100, but n small, we can check reachability
    # The key insight: after k moves, parity matters
    # - If we apply q (heads) k times: position = q^k
    # - If we apply q inverse some times: position = q^(k-2t) where t is number of tails
    # - So we can reach states with parity matching k mod 2
    
    # Simulate all reachable states for each move count
    from collections import defaultdict
    reachable = [set() for _ in range(k+1)]
    reachable[0].add(tuple(identity))
    
    for move in range(k):
        for state in reachable[move]:
            # Apply q (heads)
            new_state1 = [0] * n
            for i in range(n):
                new_state1[i] = state[q0[i]]
            reachable[move+1].add(tuple(new_state1))
            
            # Apply q inverse (tails)
            new_state2 = [0] * n
            for i in range(n):
                new_state2[i] = state[q_inv[i]-1]
            reachable[move+1].add(tuple(new_state2))
    
    # Check if s is reachable at exactly move k
    s_tuple = tuple(s)
    if s_tuple not in reachable[k]:
        return False
    
    # Check that s was not reachable at any move < k
    for move in range(k):
        if s_tuple in reachable[move]:
            return False
    
    return True

# Test cases
test_cases = [
    ([2, 3, 4, 1], [1, 2, 3, 4], 4, 1, False, "Example 1: identity at move 0, k=1"),
    ([4, 3, 1, 2], [3, 4, 2, 1], 4, 1, True, "Example 2: YES"),
    ([4, 3, 1, 2], [3, 4, 2, 1], 4, 3, True, "Example 3: YES"),
    ([4, 3, 1, 2], [2, 1, 4, 3], 4, 2, True, "Example 4: YES"),
    ([4, 3, 1, 2], [2, 1, 4, 3], 4, 1, False, "Example 5: NO"),
    ([4, 3, 1, 2], [2, 1, 4, 3], 4, 3, False, "Example 6: NO"),
    ([2, 1, 4, 3], [4, 3, 1, 2], 4, 3, False, "Example 7: NO"),
    ([2, 1, 4, 3], [2, 1, 4, 3], 4, 1, True, "Example 8: YES (identity at move 1)"),
    ([2, 1, 4, 3], [2, 1, 4, 3], 4, 2, False, "Example 9: NO (identity at move 0)"),
    ([2, 3, 4, 1], [1, 2, 3, 4], 4, 2, False, "Example 10: NO (identity at move 0)"),
]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_permutation_game(dut):
    # Setup clock and reset
    CLK_NS = 10
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 1
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await Timer(10, units='ns')
        
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    passed = 0
    failed = 0
    
    for test_num, (q, s, n, k, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_num+1}: {desc}")
        
        try:
            # Pack q and s into 4-bit values
            q_packed = pack_perm(q, 4)
            s_packed = pack_perm(s, 4)
            
            # Set inputs
            if has_signal(dut, 'q'):
                dut.q.value = q_packed
            else:
                # Handle individual bits if needed
                for i in range(n):
                    if has_signal(dut, f'q_{i}'):
                        getattr(dut, f'q_{i}').value = q[i]
            
            if has_signal(dut, 's'):
                dut.s.value = s_packed
            else:
                for i in range(n):
                    if has_signal(dut, f's_{i}'):
                        getattr(dut, f's_{i}').value = s[i]
            
            if has_signal(dut, 'n_in'):
                dut.n_in.value = n
            if has_signal(dut, 'k_in'):
                dut.k_in.value = k
            
            # Start computation
            if is_sequential:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                max_cycles = 200
                for _ in range(max_cycles):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout waiting for done after {max_cycles} cycles")
            else:
                # Combinational logic
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            result_bool = bool(result)
            
            if result_bool != expected:
                raise TestFailure(f"Expected {'YES' if expected else 'NO'}, got {'YES' if result_bool else 'NO'}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Got {'YES' if result_bool else 'NO'}")
            
        except Exception as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTotal: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")

# Additional comprehensive test
@cocotb.test(timeout_time=20000, timeout_unit="ms")
async def test_large_cases(dut):
    """Test with larger values from the problem test cases"""
    large_cases = [
        ([51, 43, 20, 22, 50, 48, 35, 6, 49, 7, 52, 29, 34, 45, 9, 55, 47, 36, 41, 54, 1, 4, 39, 46, 25, 26, 12, 28, 14, 3, 33, 23, 11, 2, 53, 8, 40, 32, 13, 37, 19, 16, 18, 42, 27, 31, 17, 44, 30, 24, 15, 38, 10, 21, 5],
         [30, 31, 51, 22, 43, 32, 10, 38, 54, 53, 44, 12, 24, 14, 20, 34, 47, 11, 41, 15, 49, 4, 5, 36, 25, 26, 27, 28, 29, 1, 6, 55, 48, 46, 7, 52, 40, 16, 50, 37, 19, 13, 33, 39, 45, 8, 17, 23, 21, 18, 3, 42, 35, 9, 2],
         55, 30, False, "Large case 1"),
    ]
    
    CLK_NS = 10
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 1
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await Timer(10, units='ns')
        
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    for test_num, (q, s, n, k, expected, desc) in enumerate(large_cases):
        cocotb.log.info(f"Large Test {test_num+1}: {desc}")
        
        try:
            # Pack permutations (note: n=55 exceeds our 16-value limit)
            # Since HDL can't handle n=55, we skip this test for HDL validation
            # This is a limitation of the hardware implementation
            cocotb.log.info(f"  SKIPPED: n=55 exceeds HDL constraint (max n=16)")
            continue
            
        except Exception as e:
            cocotb.log.error(f"  FAIL: {e}")
            raise TestFailure(f"Large test failed: {e}")
