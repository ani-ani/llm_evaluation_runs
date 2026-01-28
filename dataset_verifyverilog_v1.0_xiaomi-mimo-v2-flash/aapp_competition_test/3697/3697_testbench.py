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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=1000):
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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_election_module(dut):
    CLK_NS = 10
    
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (3, 1, 5, 4, [1, 2, 1, 3], [1, 3, 3]),  # Example 1
        (3, 1, 5, 3, [1, 3, 1], [2, 3, 2]),    # Example 2
        (3, 2, 5, 3, [1, 3, 1], [1, 2, 2]),    # Example 3
        (1, 1, 1, 1, [1], [1]),                 # Edge case: single candidate
        (2, 1, 1, 1, [2], [3, 1]),             # Edge case: candidate 1 gets no votes
    ]
    
    passed = failed = 0
    
    for tc_idx, (n, k, m, a, votes, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {tc_idx+1}: n={n}, k={k}, m={m}, a={a}")
        
        try:
            if has_signal(dut, 'clk'):
                await reset_dut(dut)
            
            # Load parameters
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 4)
            if has_signal(dut, 'k'):
                dut.k.value = clamp_to_width(k, 4)
            if has_signal(dut, 'm'):
                dut.m.value = clamp_to_width(m, 7)
            if has_signal(dut, 'a'):
                dut.a.value = clamp_to_width(a, 7)
            
            # Load votes sequentially
            if has_signal(dut, 'vote_en'):
                for i in range(a):
                    dut.vote_index.value = clamp_to_width(i, 7)
                    dut.vote_cand.value = clamp_to_width(votes[i], 4)
                    dut.vote_en.value = 1
                    await RisingEdge(dut.clk)
                    dut.vote_en.value = 0
                    await RisingEdge(dut.clk)
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
            
            # Read results
            results = []
            for cand_idx in range(n):
                if has_signal(dut, f'result_{cand_idx}'):
                    val = int(getattr(dut, f'result_{cand_idx}').value)
                    results.append(val)
                elif has_signal(dut, 'result'):
                    # If result is a bus
                    result_val = int(dut.result.value)
                    # Extract bits for this candidate (if packed)
                    bits_per_cand = 3
                    val = (result_val >> (cand_idx * bits_per_cand)) & 0x7
                    results.append(val)
                elif has_signal(dut, 'candidate_idx') and has_signal(dut, 'result'):
                    # Sequential reading
                    for i in range(n):
                        await Timer(CLK_NS * 2, units='ns')
                        val = int(dut.result.value)
                        results.append(val)
                    break
            
            # Verify results
            if len(results) != len(expected):
                raise TestFailure(f"Expected {len(expected)} results, got {len(results)}")
            
            for i, (got, exp) in enumerate(zip(results, expected)):
                if got != exp:
                    raise TestFailure(f"Candidate {i+1}: Expected {exp}, got {got}")
            
            cocotb.log.info(f"PASS: {expected}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
