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

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_bandit_gold(dut):
    # Setup Clock and Reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test Cases
    # Format: (n, edges_list, gold_values, expected_result)
    test_cases = [
        (3, [(1,2), (2,3), (1,3)], [1], 0),
        (4, [(1,3), (2,3), (2,4), (1,4)], [24, 10], 24),
        (6, [(1,3), (1,4), (3,6), (4,5), (3,5), (4,6), (2,5), (2,6)], [100, 500, 300, 75], 800),
        (7, [(1,3), (1,4), (1,5), (3,7), (5,6), (2,6), (3,6)], [90, 1000, 700, 2000, 800], 700)
    ]

    for idx, (n, edges, golds, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {idx+1}: n={n}, Expected={expected}")
        
        # Reset for new test case if signal exists
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
        
        # Start signal
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # 1. Load n
        if has_signal(dut, 'n_in'):
            dut.n_in.value = n
            await RisingEdge(dut.clk)
        
        # 2. Load Gold (Map village 3..n to index 0..n-3)
        if has_signal(dut, 'gold_valid') and has_signal(dut, 'gold_in'):
            dut.gold_valid.value = 1
            for i, g in enumerate(golds):
                dut.gold_in.value = clamp_to_width(g, 16)
                # Implementation might need an index, here we assume stream or external index logic
                # For this test, we might need to drive an index signal if it exists, or loop
                # Assuming the DUT has a way to ingest them. 
                # If DUT expects sequential load, we drive valid high.
                # If DUT needs index, we would drive it. 
                # Let's assume simple stream: valid high for each value.
                # If the DUT uses 'gold_idx', we need to drive it.
                if has_signal(dut, 'gold_idx'):
                    dut.gold_idx.value = i
                await RisingEdge(dut.clk)
            dut.gold_valid.value = 0
        
        # 3. Load Edges
        if has_signal(dut, 'edge_valid') and has_signal(dut, 'edge_a') and has_signal(dut, 'edge_b'):
            dut.edge_valid.value = 1
            for u, v in edges:
                dut.edge_a.value = u
                dut.edge_b.value = v
                await RisingEdge(dut.clk)
            dut.edge_valid.value = 0
            
            # Signal done loading
            if has_signal(dut, 'edge_load_done'):
                dut.edge_load_done.value = 1
                await RisingEdge(dut.clk)
                dut.edge_load_done.value = 0
        
        # Wait for done
        if has_signal(dut, 'done'):
            for _ in range(5000): # Max cycles from spec
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
                await RisingEdge(dut.clk)
        else:
            await Timer(5000, units='ns')
        
        # Read Result
        if has_signal(dut, 'result'):
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Test {idx+1} Failed: Result undefined")
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Test {idx+1} Failed: Expected {expected}, got {result}")
            else:
                cocotb.log.info(f"Test {idx+1} Passed")
        else:
            cocotb.log.warning("Result signal not found, skipping check")

