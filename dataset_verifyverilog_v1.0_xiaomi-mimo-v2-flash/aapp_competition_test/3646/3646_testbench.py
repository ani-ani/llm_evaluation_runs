import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Global constants
DATA_WIDTH = 8
NODE_WIDTH = 4
MAX_NODES = 16
CLK_NS = 10
MAX_CYCLES = 2000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def simulate_python_logic(spots):
    """
    Reference Python implementation for small graphs (N <= 16).
    Returns the max reachable index (0-based).
    """
    n = len(spots)
    if n == 0:
        return 0
    reachable = [False] * n
    reachable[0] = True
    changed = True
    while changed:
        changed = False
        for u in range(n):
            if reachable[u]:
                for v in range(n):
                    if not reachable[v]:
                        if spots[u] + spots[v] == abs(u - v):
                            reachable[v] = True
                            changed = True
    for i in range(n - 1, -1, -1):
        if reachable[i]:
            return i
    return 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pebble_jump(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test cases: (spots list)
    test_cases = [
        [2, 1, 0, 1, 2, 3, 3],          # Sample 1
        [7, 6, 1, 4, 1, 2, 1, 4, 1, 4, 5], # Sample 2
        [0],                             # Single node
        [10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10], # Impossible jumps
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], # Specific pattern
    ]

    passed = 0
    failed = 0

    for i, spots in enumerate(test_cases):
        n = len(spots)
        desc = f"Test case {i+1}: N={n}, spots={spots}"
        cocotb.log.info(desc)
        
        try:
            # 1. Calculate expected result using reference logic
            expected = simulate_python_logic(spots)
            
            # 2. Drive DUT inputs
            dut.num_nodes.value = n
            
            # Handle nodes_spots array input
            # If the HDL uses unpacked array (nodes_spots[0], nodes_spots[1]...)
            if has_signal(dut, 'nodes_spots_0'):
                for idx in range(MAX_NODES):
                    val = spots[idx] if idx < n else 0
                    getattr(dut, f'nodes_spots_{idx}').value = clamp_to_width(val, DATA_WIDTH)
            # If it uses packed array (unlikely for 2D simulation but checking)
            elif has_signal(dut, 'nodes_spots'):
                # If it is an unpacked array, we iterate
                try:
                    for idx in range(n):
                        dut.nodes_spots[idx].value = clamp_to_width(spots[idx], DATA_WIDTH)
                    # Initialize unused entries to 0 for safety
                    for idx in range(n, MAX_NODES):
                        dut.nodes_spots[idx].value = 0
                except Exception:
                    # Fallback: if the tool doesn't support direct array assignment in cocotb
                    # we rely on the driver logic being robust or the previous case
                    pass
            
            # 3. Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # 4. Wait for done
            await wait_for_done(dut)
            
            # 5. Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result = int(dut.result.value)
            
            # 6. Verify
            if result != expected:
                raise TestFailure(f"Expected max index {expected}, got {result}")
            
            passed += 1
            
            # Prepare for next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
            # Reset before next test
            await reset_dut(dut)

    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")
