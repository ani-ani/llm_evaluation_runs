import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MAX_N = 16
DATA_WIDTH = 16
IDX_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 1024

# Helpers
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
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Function to compute expected result (Python simulation)
def compute_expected(N, debt_to, debt_amt):
    visited = [False] * N
    total = 0
    for i in range(N):
        if not visited[i]:
            cycle = []
            cur = i
            while not visited[cur]:
                visited[cur] = True
                cycle.append(cur)
                cur = debt_to[cur]
            # Check if cycle exists (cur is in current path)
            if cur in cycle:
                start_idx = cycle.index(cur)
                min_amt = min(debt_amt[node] for node in cycle[start_idx:])
                total += min_amt
    return total

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_debt_payment(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just wait a bit
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        # Example 1: N=4, cycle 1-2 (100 each), cycle 3-4 (70 each)
        {
            'N': 4,
            'debt_to': [1, 0, 3, 2],  # 0->1, 1->0, 2->3, 3->2
            'debt_amt': [100, 100, 70, 70],
            'expected': 170  # min(100,100) + min(70,70) = 100+70 = 170
        },
        # Example 2: N=3, 0->1 (120), 1->2 (50), 2->1 (80)
        {
            'N': 3,
            'debt_to': [1, 2, 1],  # 0->1, 1->2, 2->1 (cycle 1-2)
            'debt_amt': [120, 50, 80],
            'expected': 150  # min(50,80) = 50 for cycle 1-2, 0->1 separate
        },
        # Example 3: N=5, 0->2 (30), 1->2 (20), 2->3 (100), 3->4 (40), 4->2 (60)
        {
            'N': 5,
            'debt_to': [2, 2, 3, 4, 2],
            'debt_amt': [30, 20, 100, 40, 60],
            'expected': 110  # Cycle 2-3-4: min(100,40,60)=40, 0->2 and 1->2 feed cycle
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: N={tc['N']}")
        
        try:
            # Set N
            if has_signal(dut, 'N'):
                dut.N.value = clamp_to_width(tc['N'], IDX_WIDTH)
            
            # Set debt_to array
            if hasattr(dut, 'debt_to'):
                # Individual access for array
                for node in range(tc['N']):
                    dut.debt_to[node].value = clamp_to_width(tc['debt_to'][node], IDX_WIDTH)
            else:
                # Check for individual ports
                for node in range(tc['N']):
                    port_name = f'debt_to_{node}'
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = clamp_to_width(tc['debt_to'][node], IDX_WIDTH)
            
            # Set debt_amt array
            if hasattr(dut, 'debt_amt'):
                for node in range(tc['N']):
                    dut.debt_amt[node].value = clamp_to_width(tc['debt_amt'][node], DATA_WIDTH)
            else:
                for node in range(tc['N']):
                    port_name = f'debt_amt_{node}'
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = clamp_to_width(tc['debt_amt'][node], DATA_WIDTH)
            
            # Wait for inputs to settle
            await Timer(10, units='ns')
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                
            else:
                # Combinational: result is immediately available
                await Timer(10, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            
            # Compute expected
            expected = compute_expected(tc['N'], tc['debt_to'], tc['debt_amt'])
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASSED: result={result}")
            
            # Reset for next test
            if is_seq:
                await reset_dut(dut, cycles=2)
            else:
                await Timer(10, units='ns')
                
        except TestFailure as e:
            cocotb.log.error(f"  FAILED: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")