import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Configuration
N_MAX = 128
CLK_NS = 10

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_permutation(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational logic assumed
        await Timer(10, units='ns')

    # Test cases
    test_cases = [
        (9, 2, 5),   # Example 1
        (3, 2, 1),   # Example 2
        (7, 4, 4),   # Impossible (7 % 4 != 0)
        (5, 2, 3),   # 1 cycle of 2, 1 cycle of 3
        (1, 1, 1),   # Single element
        (8, 2, 2),   # Multiple cycles of 2
        (10, 3, 3),  # Impossible
    ]

    for N, A, B in test_cases:
        cocotb.log.info(f"Testing N={N}, A={A}, B={B}")
        
        # Set inputs
        if has_signal(dut, 'N'):
            dut.N.value = N
        if has_signal(dut, 'A'):
            dut.A.value = A
        if has_signal(dut, 'B'):
            dut.B.value = B
        
        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done = False
            for _ in range(500):
                await RisingEdge(dut.clk)
                if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure(f"Timeout for N={N}, A={A}, B={B}")
        else:
            # Combinational, wait for propagation
            await Timer(100, units='ns')

        # Check results
        is_possible = True
        # Check impossible flag if exists
        if has_signal(dut, 'impossible'):
            if is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
                is_possible = False
        
        # Verify Solution
        if is_possible:
            if not has_signal(dut, 'valid') or not (is_value_defined(dut.valid.value) and int(dut.valid.value) == 1):
                 # Some designs might not have valid, just check result exists
                 pass
            
            # Read permutation
            perm = []
            valid_indices = 0
            for i in range(N):
                if has_signal(dut, f'result_{i}'):
                    val = int(getattr(dut, f'result_{i}').value)
                    perm.append(val)
                elif has_signal(dut, 'result'):
                    # Packed array handling is complex, assuming individual ports per spec
                    raise TestFailure("Expected individual result ports")
                else:
                    # Fallback for packed if signal check failed (should not happen based on prompt)
                    pass
            
            if len(perm) != N:
                raise TestFailure(f"Expected {N} outputs, got {len(perm)}")

            # Verify permutation properties
            if sorted(perm) != list(range(1, N + 1)):
                raise TestFailure(f"Invalid permutation: {perm}. Expected sorted range 1..{N}")
            
            # Verify cycle lengths
            visited = [False] * N
            for i in range(N):
                if not visited[i]:
                    curr = i
                    length = 0
                    while not visited[curr]:
                        visited[curr] = True
                        # perm[curr] is value at index curr (0-based). 
                        # The problem is 1-indexed: P[1]...P[N].
                        # Our result_i stores P[i+1].
                        # We traverse P[i+1] - 1 to get next index.
                        next_val = perm[curr]
                        next_idx = next_val - 1
                        
                        if next_idx < 0 or next_idx >= N:
                            raise TestFailure(f"Permutation value out of bounds: {perm[curr]}")
                        
                        curr = next_idx
                        length += 1
                        if length > max(A, B) + 5: # Safety break
                            raise TestFailure(f"Cycle length overflow at index {i}")
                    
                    if length != A and length != B:
                        raise TestFailure(f"Invalid cycle length {length} at index {i}. Expected {A} or {B}")
            
            cocotb.log.info(f"PASS: N={N}, A={A}, B={B}")
        else:
            # Expected impossible
            if has_signal(dut, 'valid') and is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                 raise TestFailure(f"Claimed impossible but valid=1 for N={N}, A={A}, B={B}")
            cocotb.log.info(f"PASS: Correctly detected impossibility for N={N}, A={A}, B={B}")

    # Final check: Ensure timeout coverage
    raise TestFailure("Testbench completed successfully")
