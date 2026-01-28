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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_lms_sequence(dut):
    # Setup
    CLK_NS = 10
    MAX_N = 16  # Scaled for test
    MAX_CYCLES = 5000
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (N, K, expected_behavior)
    test_cases = [
        (4, 3, "possible"),  # Example 1
        (5, 1, "impossible"), # Example 2
        (5, 5, "sorted"),     # Sorted order
        (3, 2, "possible"),   # Another possible
        (2, 1, "impossible"), # K=1 with N>1
        (1, 1, "sorted"),     # N=1
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, K, exp_type) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: N={N}, K={K}, expecting {exp_type}")
        
        try:
            # Set inputs
            dut.N.value = clamp_to_width(N, 20)
            dut.K.value = clamp_to_width(K, 20)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Collect output sequence
            seq = []
            error_found = False
            
            # Monitor until done or error
            cycles = 0
            while cycles < MAX_CYCLES:
                await RisingEdge(dut.clk)
                cycles += 1
                
                if is_value_defined(dut.error.value) and int(dut.error.value) == 1:
                    error_found = True
                    cocotb.log.info(f"  Error signal received")
                    break
                
                if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                    val = int(dut.data.value)
                    seq.append(val)
                    cocotb.log.info(f"  Valid output: {val}")
                
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            
            # Validate
            if exp_type == "impossible":
                if not error_found:
                    raise TestFailure(f"Expected error for N={N}, K={K}, but got sequence: {seq}")
                if not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                    raise TestFailure("Done not set after error")
            else:
                if error_found:
                    raise TestFailure(f"Unexpected error for N={N}, K={K}")
                
                if len(seq) != N:
                    raise TestFailure(f"Expected {N} numbers, got {len(seq)}: {seq}")
                
                # Check if numbers are 1..N exactly once
                sorted_seq = sorted(seq)
                if sorted_seq != list(range(1, N + 1)):
                    raise TestFailure(f"Invalid permutation: {seq}")
                
                # Check monotone subsequence length property
                # Compute LIS and LDS
                n = len(seq)
                lis = [1] * n
                for i in range(n):
                    for j in range(i):
                        if seq[i] > seq[j] and lis[i] < lis[j] + 1:
                            lis[i] = lis[j] + 1
                lds = [1] * n
                for i in range(n):
                    for j in range(i):
                        if seq[i] < seq[j] and lds[i] < lds[j] + 1:
                            lds[i] = lds[j] + 1
                max_mono = max(max(lis), max(lds)) if n > 0 else 0
                
                if max_mono != K:
                    raise TestFailure(f"Longest monotone subsequence is {max_mono}, expected {K}")
                
                cocotb.log.info(f"  Sequence: {seq}, LIS={max(lis)}, LDS={max(lds)}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
