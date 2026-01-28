import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
YEAR_WIDTH = 12
POP_WIDTH = 24
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_tree_harvester(dut):
    """Test TreeHarvester with scaled test cases"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (valid_count, [S0,B0,Y0,I0], [S1,B1,Y1,I1], expected_result)
    # Case 1: Single species, peak at 100
    # S=0, B=5, Y=10, I=10 → peak at year 15 with 100 trees
    test_cases = [
        (1, [0,5,10,10], [0,0,0,0], 100),
        # Case 2: Two species, max at year 9 = 145
        # S=0,B=4,Y=5,I=10 → peak at 9: 50
        # S=10,B=1,Y=10,I=10 → at 9: 90
        # Total at 9: 140? Wait, need to verify
        # Actually: species1: 0+10*(9-4)=50, species2: 10+10*(9-1)=90, total=140
        # But expected is 145. Let me recalculate with correct formulas.
        # For species2 at year 9: B=1, Y=10, so B+Y=11. Year 9 is increasing.
        # Population = S + I*(t-B) = 10 + 10*(9-1) = 10 + 80 = 90. Correct.
        # Species3: S=0,B=0,Y=5,I=5 → at year 9: B+Y=5, decreasing, so pop = 5*5 - 5*(9-5) = 25-20=5
        # Wait, I need species3. The test case should have 3 species but we only have 2 ports.
        # Let's use a different test case.
        # Case 2: Two species with peaks at different times
        # Species1: S=0,B=0,Y=2,I=10 → peak at year 2 with 20
        # Species2: S=0,B=3,Y=2,I=10 → peak at year 5 with 20
        # At year 2: total = 20 + 0 = 20
        # At year 3: total = 10 + 0 = 10
        # At year 4: total = 0 + 10 = 10
        # At year 5: total = 0 + 20 = 20
        # Maximum = 20
        (2, [0,0,2,10], [0,3,2,10], 20),
        # Case 3: Overlapping peaks
        # Species1: S=0,B=0,Y=5,I=2 → peak at 5: 10
        # Species2: S=0,B=2,Y=5,I=2 → peak at 7: 10
        # Year 5: species1=10, species2= (5-2)*2=6 → total 16
        # Year 6: species1=8, species2= (6-2)*2=8 → total 16
        # Year 7: species1=6, species2=10 → total 16
        # Year 2: species1=4, species2=0 → 4
        # Maximum = 16
        (2, [0,0,5,2], [0,2,5,2], 16),
        # Case 4: One species constant (I=0)
        # Species1: S=5,B=0,Y=0,I=0 → constant 5
        # Species2: S=0,B=1,Y=2,I=10 → peak at 3: 20
        # Maximum = max(5, 5+20) = 25 at year 3
        (2, [5,0,0,0], [0,1,2,10], 25),
        # Case 5: Simple decreasing
        # Species1: S=20,B=0,Y=0,I=10 → starts at 20, immediately decreases
        # At year 0: 20
        # At year 1: 20-10=10
        # At year 2: 0
        # Maximum = 20
        (1, [20,0,0,10], [0,0,0,0], 20),
        # Case 6: Both species, only one active
        (2, [0,5,10,10], [0,0,0,0], 100),
    ]
    
    passed = 0
    failed = 0
    
    for i, (vcount, data0, data1, expected) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: valid_count={vcount}, expected={expected}")
        
        # Drive inputs
        dut.valid_count.value = vcount
        
        # Assign species 0
        dut.S_0.value = clamp_to_width(data0[0], DATA_WIDTH)
        dut.B_0.value = clamp_to_width(data0[1], DATA_WIDTH)
        dut.Y_0.value = clamp_to_width(data0[2], DATA_WIDTH)
        dut.I_0.value = clamp_to_width(data0[3], DATA_WIDTH)
        
        # Assign species 1
        dut.S_1.value = clamp_to_width(data1[0], DATA_WIDTH)
        dut.B_1.value = clamp_to_width(data1[1], DATA_WIDTH)
        dut.Y_1.value = clamp_to_width(data1[2], DATA_WIDTH)
        dut.I_1.value = clamp_to_width(data1[3], DATA_WIDTH)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"  FAIL: result undefined")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        # Allow small rounding differences for large values
        if result == expected:
            dut._log.info(f"  PASS: result={result}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")