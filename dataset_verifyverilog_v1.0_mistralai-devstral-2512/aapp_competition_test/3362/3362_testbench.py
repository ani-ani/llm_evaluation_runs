import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_lava(dut):
    # Reset and Clock
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.map_write.value = 0
    dut.map_in.value = 0
    dut.map_addr.value = 0
    dut.step_elsa.value = 0
    dut.step_father.value = 0
    
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
        
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

    # --- Test Case 1: GO FOR IT (Elsa wins) ---
    # Map: 4x4
    # WWWW
    # WSBB  (S at 1,1)
    # WWWW  (G at 3,3)
    # WBWG
    # Elsa step 2 (Euclidean): 1,1 -> 2,2 (dist ~1.4) -> 3,3 (dist ~1.4). Total 2 moves.
    # Father step 3 (Manhattan): 1,1 -> 1,4 (out of bounds or B) -> ... needs 2 moves? 
    # Actually Father needs to go 1,1 -> 1,4 (dist 3) invalid (B), 2,1 -> 2,4 invalid.
    # Let's use the explicit sample logic.
    # Elsa wins if she reaches G in fewer steps than Father.
    
    map_data = [
        'WWWW',
        'WSBB',
        'WWWW',
        'WBWG'
    ]
    
    # Load Map
    # Map chars: S=0, W=1, G=2, B=3
    char_map = {'S': 0, 'W': 1, 'G': 2, 'B': 3}
    
    for r in range(4):
        for c in range(4):
            dut.map_addr.value = r * 16 + c
            dut.map_in.value = char_map[map_data[r][c]]
            dut.map_write.value = 1
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')
            dut.map_write.value = 0
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')

    # Fill rest with B (3)
    for i in range(16*16):
        if i >= 4*4:
            dut.map_addr.value = i
            dut.map_in.value = 3 # B
            dut.map_write.value = 1
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')
            dut.map_write.value = 0
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')

    # Inputs
    dut.step_elsa.value = 2 # A=2
    dut.step_father.value = 3 # F=3
    
    # Start
    dut.start.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    else: await Timer(100, units='ns')
    dut.start.value = 0
    
    # Wait for done
    timeout = 1000
    found = False
    for _ in range(timeout):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        else: await Timer(100, units='ns')
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            found = True
            break
            
    if not found:
        raise TestFailure("Test 1: Timeout waiting for done")
        
    result = int(dut.result.value)
    if result != 2: # GO FOR IT
        raise TestFailure(f"Test 1: Expected 2 (GO FOR IT), got {result}")

    # --- Test Case 2: SUCCESS (Both reach same time) ---
    # Map: 1x2
    # GS
    # S at 1, G at 0. 
    # Elsa step 1: Euclidean distance 1. 1 move.
    # Father step 1: Manhattan distance 1. 1 move.
    
    dut.rst_n.value = 0
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

    # Load Map
    for r in range(1):
        for c in range(2):
            dut.map_addr.value = r * 16 + c
            val = 0 # S
            if map_data[r][c] == 'G': val = 2
            dut.map_in.value = val
            dut.map_write.value = 1
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')
            dut.map_write.value = 0
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')
            
    # Fill rest with B
    for i in range(16*16):
        if i >= 2:
            dut.map_addr.value = i
            dut.map_in.value = 3 # B
            dut.map_write.value = 1
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')
            dut.map_write.value = 0
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')

    dut.step_elsa.value = 1
    dut.step_father.value = 1
    
    dut.start.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    else: await Timer(100, units='ns')
    dut.start.value = 0
    
    found = False
    for _ in range(timeout):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        else: await Timer(100, units='ns')
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            found = True
            break
            
    if not found:
        raise TestFailure("Test 2: Timeout waiting for done")
        
    result = int(dut.result.value)
    if result != 1: # SUCCESS
        raise TestFailure(f"Test 2: Expected 1 (SUCCESS), got {result}")

    # --- Test Case 3: NO WAY (Blocked) ---
    # Map: 1x3
    # SBG
    # Elsa step 2: Can jump over B (distance 2). Reaches G.
    # Father step 1: Cannot jump over B. Distance to G is 2 > 1. Stuck.
    # Actually Father cannot step on B. So Father cannot reach G.
    # Elsa can reach G.
    # Result: GO FOR IT.
    
    # Let's try to block Elsa too.
    # Map: 1x3
    # SBB (Start at 0, G at 2?) No G.
    # Or S at 0, W at 1, B at 2. No G.
    # Let's do S at 0, G at 2. Step 1.
    # Elsa: dist 2 > 1. Fail.
    # Father: dist 2 > 1. Fail.
    # Output NO WAY.
    
    dut.rst_n.value = 0
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

    # Load Map (S at 0, G at 2)
    # We need to ensure other cells are B
    dut.map_addr.value = 0
    dut.map_in.value = 0 # S
    dut.map_write.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.map_write.value = 0
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

    dut.map_addr.value = 1
    dut.map_in.value = 3 # B
    dut.map_write.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.map_write.value = 0
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

    dut.map_addr.value = 2
    dut.map_in.value = 2 # G
    dut.map_write.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.map_write.value = 0
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

    for i in range(3, 16*16):
        dut.map_addr.value = i
        dut.map_in.value = 3 # B
        dut.map_write.value = 1
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        dut.map_write.value = 0
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

    dut.step_elsa.value = 1
    dut.step_father.value = 1
    
    dut.start.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    else: await Timer(100, units='ns')
    dut.start.value = 0
    
    found = False
    for _ in range(timeout):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        else: await Timer(100, units='ns')
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            found = True
            break
            
    if not found:
        raise TestFailure("Test 3: Timeout waiting for done")
        
    result = int(dut.result.value)
    if result != 0: # NO WAY
        raise TestFailure(f"Test 3: Expected 0 (NO WAY), got {result}")
