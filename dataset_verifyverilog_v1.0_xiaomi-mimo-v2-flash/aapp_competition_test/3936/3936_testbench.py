import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 100
MOD = 1000000007

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(CLK_NS, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    if has_signal(dut, 'done'):
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value)==1:
                return True
        raise TestFailure(f"Timeout after {max_cycles} cycles")
    return False

# Test function
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_domino_coloring(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (N, S1, S2, expected_result)
    test_cases = [
        (3, "aab", "ccb", 6),
        (1, "Z", "Z", 3),
        (2, "EE", "CC", 6),
        (2, "xj", "xj", 6),
        (4, "TTVV", "IIKK", 18),
        (52, "RvvttdWIyyPPQFFZZssffEEkkaSSDKqcibbeYrhAljCCGGJppHHn", "RLLwwdWIxxNNQUUXXVVMMooBBaggDKqcimmeYrhAljOOTTJuuzzn", 958681902)
    ]
    
    for case_num, (N, s1, s2, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test case {case_num+1}: N={N}, S1={s1}, S2={s2}")
        
        if is_seq:
            # Sequential processing: one character pair per cycle
            state = 0  # 0=vertical prev, 1=horizontal prev
            ans = 1
            idx = 0
            
            while idx < N:
                # Set inputs
                dut.s1_in.value = ord(s1[idx])
                dut.s2_in.value = ord(s2[idx])
                dut.idx_in.value = idx
                dut.is_last.value = 1 if idx == N-1 else 0
                
                if idx == 0:
                    if has_signal(dut, 'start'):
                        dut.start.value = 1
                        await RisingEdge(dut.clk)
                        dut.start.value = 0
                    else:
                        await RisingEdge(dut.clk)
                else:
                    await RisingEdge(dut.clk)
                
                # Check for done
                if has_signal(dut, 'done') and int(dut.done.value) == 1:
                    break
                
                # Update state locally for verification
                if s1[idx] == s2[idx]:  # vertical
                    if state == 0:
                        ans = (ans * 2) % MOD
                    # state remains 0
                    idx += 1
                else:  # horizontal
                    if state == 0:
                        ans = (ans * 2) % MOD
                    else:
                        ans = (ans * 3) % MOD
                    state = 1
                    idx += 2
            
            # Wait for final output
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            
        else:
            # Combinational: feed all data at once
            # This assumes a sequential implementation inside
            # For combinational, we'd need a different interface
            # Here we simulate sequential access
            for i in range(N):
                dut.s1_in.value = ord(s1[i])
                dut.s2_in.value = ord(s2[i])
                dut.idx_in.value = i
                dut.is_last.value = 1 if i == N-1 else 0
                await Timer(CLK_NS, units='ns')
            
            if is_value_defined(dut.result.value):
                result = int(dut.result.value)
            else:
                raise TestFailure("Combinational result undefined")
        
        # Verify result
        if result != expected:
            raise TestFailure(f"Case {case_num+1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Case {case_num+1}: PASSED (result={result})")
        
        # Reset for next test
        if is_seq and case_num < len(test_cases)-1:
            await reset_dut(dut)
