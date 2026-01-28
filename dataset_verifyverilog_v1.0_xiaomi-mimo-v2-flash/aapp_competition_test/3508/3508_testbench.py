import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5, timeout_unit='ms')
async def test_pillar_collapse(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test Case 1: n=5, [1341, 2412, 1200, 3112, 2391]
    # Expected: 3 1
    # In scaled problem (n=5): 
    # We need to calculate expected damage based on Verilog logic.
    # Logic: Load = 1000 / distance.
    # Destroy pillar 1:
    # P0: dist 1 -> load 1000 (OK 1341)
    # P2: dist 1 -> load 1000 (OK 1200)
    # P3: dist 2 -> load 500 (OK 3112)
    # P4: dist 3 -> load 333 (OK 2391)
    # Total destroyed: 1 (initial). 
    # Wait, sample output says 3 1. 
    # Let's re-read problem. 'Each pillar supports part closest to it'.
    # Weight density = 1000 kN.
    # If pillar 1 is destroyed, the gap between 0 and 2 is covered by 0 and 2.
    # Distance between 0 and 2 is 2 units. 
    # Load on 0 from right: 500. Load on 2 from left: 500.
    # P0: 1000 (self) + 500 = 1500 > 1341? YES. Collapse.
    # P2: 1000 (self) + 500 = 1500 > 1200? YES. Collapse.
    # P3: 1000 (self). Dist 1 to 2 (collapsed). New dist to 0 is 3? 
    # Actually, cascading: 
    # P1 destroyed.
    # P0 fails (1500 > 1341).
    # P2 fails (1500 > 1200).
    # Now P3 sees gap P2-P4 (dist 2). Load 500.
    # P3 total: 1000 + 500 = 1500 < 3112. OK.
    # P4 total: 1000. OK.
    # Total destroyed: 1, 0, 2 = 3 pillars.
    # So logic is correct.
    
    # Test Case 2: n=5, [1004, 1003, 1002, 1001, 1000]
    # Expected: 5 0
    # Destroy P0:
    # P1 gets load from P0: 1000. Total 2000 > 1003. Collapse.
    # P2 gets load from P1: 500. Total 1500 > 1002. Collapse.
    # P3 gets load from P2: 333. Total 1333 > 1001. Collapse.
    # P4 gets load from P3: 250. Total 1250 > 1000. Collapse.
    # All destroyed.

    n = 5
    b_vals = [1341, 2412, 1200, 3112, 2391]
    
    # Load values into DUT
    dut.n.value = n
    for i in range(n):
        dut.b_addr.value = i
        dut.b_data_in.value = b_vals[i]
        dut.b_wr.value = 1
        await RisingEdge(dut.clk)
    dut.b_wr.value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    done = False
    for _ in range(2048):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
            
    if not done:
        raise TestFailure("Timeout waiting for done")
        
    damage = int(dut.max_damage.value)
    idx = int(dut.best_idx.value)
    
    # Verify result for Case 1
    if damage != 3 or idx != 1:
        # Allow for other valid answers? Problem says 'any will do' for ties.
        # Strict check for this specific case.
        # Check if we got max damage 3 at least. 
        # Actually, 3 1 is unique max for this case usually.
        if damage != 3:
             raise TestFailure(f"Case 1 Failed: Expected damage 3, got {damage}")
        # If damage is 3 but idx is different, check if that idx also gives 3.
        # For now, assert strict match for simplicity unless logic proves otherwise.
        pass # We will check strictly

    # Run Case 2
    cocotb.log.info(f"Case 1 Result: Damage {damage}, Index {idx}")
    if damage != 3 or idx != 1:
        raise TestFailure(f"Case 1 failed: Expected 3 1, got {damage} {idx}")

    # Reset for Case 2
    await reset_dut(dut)
    b_vals = [1004, 1003, 1002, 1001, 1000]
    dut.n.value = n
    for i in range(n):
        dut.b_addr.value = i
        dut.b_data_in.value = b_vals[i]
        dut.b_wr.value = 1
        await RisingEdge(dut.clk)
    dut.b_wr.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(2048):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
            
    if not done:
        raise TestFailure("Timeout waiting for done Case 2")
        
    damage = int(dut.max_damage.value)
    idx = int(dut.best_idx.value)
    
    cocotb.log.info(f"Case 2 Result: Damage {damage}, Index {idx}")
    if damage != 5:
        raise TestFailure(f"Case 2 failed: Expected damage 5, got {damage}")
    if idx != 0:
         raise TestFailure(f"Case 2 failed: Expected index 0, got {idx}")
         
    cocotb.log.info("All tests passed")
