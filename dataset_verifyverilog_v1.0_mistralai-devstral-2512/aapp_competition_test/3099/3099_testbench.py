import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    v_int = int(v)
    if v_int < 0:
        v_int = 0
    elif v_int > max_val:
        v_int = max_val
    return v_int

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Test Case 1: 4 spies, 1 enemy, 3 edges
# Input: S=4, E=1, C=3
# Edges: 0->1, 1->2, 2->3
# Enemy: 1
# Graph: 0->1(enemy) stops, 2->3 (but 1 blocks path 0->1->2)
# You message everyone directly (constraint says you can).
# Private message: cost 1 per spy.
# Public message: propagates but stops at enemies.
# To reach 0, 2, 3 without reaching enemy 1.
# Option: Message 0 (private) -> covers 0. Message 2 (public) -> covers 2,3. Total 2.

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_spy_network(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test Case 1
    dut.enemies.value = 1 << 1  # Spy 1 is enemy
    
    # Edges: 0->1, 1->2, 2->3
    # We have 32 edge slots. We fill first 3.
    # Reset edge valids
    dut.edges_valid.value = 0
    for i in range(32):
        if has_signal(dut, f'edge_src_{i}'):
            getattr(dut, f'edge_src_{i}').value = 0
            getattr(dut, f'edge_dst_{i}').value = 0
        elif has_signal(dut, 'edge_src') and hasattr(dut.edge_src, '__len__'):
             dut.edge_src[i].value = 0
             dut.edge_dst[i].value = 0

    # Helper to set edges
    def set_edge(idx, src, dst):
        if has_signal(dut, f'edge_src_{idx}'):
            getattr(dut, f'edge_src_{idx}').value = src
            getattr(dut, f'edge_dst_{idx}').value = dst
        elif has_signal(dut, 'edge_src'):
             # Assume packed array or vector array
             # If vector array (packed), we might need to shift
             # If unpacked array, assign directly
             try:
                 dut.edge_src[idx].value = src
                 dut.edge_dst[idx].value = dst
             except (TypeError, AttributeError):
                 # Fallback for packed arrays if logic is complex
                 pass
        # Mark valid
        current_valid = int(dut.edges_valid.value)
        dut.edges_valid.value = current_valid | (1 << idx)

    set_edge(0, 0, 1)
    set_edge(1, 1, 2)
    set_edge(2, 2, 3)
    
    # Start processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    # Expected: 2 (Message 0 private, Message 2 public)
    if result != 2:
        raise TestFailure(f"Test Case 1 Failed: Expected 2, got {result}")
    
    cocotb.log.info("Test Case 1 Passed")
    
    # --- Test Case 2: 4 spies, 0 enemies, 4 edges ---
    await reset_dut(dut)
    dut.enemies.value = 0
    
    # Reset edges
    dut.edges_valid.value = 0
    # Edges: 0->2, 0->1, 2->1, 2->3
    set_edge(0, 0, 2)
    set_edge(1, 0, 1)
    set_edge(2, 2, 1)
    set_edge(3, 2, 3)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    # Expected: 1 (Message 0 public covers all: 0->1, 0->2, 2->3)
    if result != 1:
        raise TestFailure(f"Test Case 2 Failed: Expected 1, got {result}")
    
    cocotb.log.info("Test Case 2 Passed")

    # --- Test Case 3: 4 spies, 2 enemies, 5 edges ---
    await reset_dut(dut)
    dut.enemies.value = (1 << 1) | (1 << 2) # Spies 1 and 2 are enemies
    
    # Reset edges
    dut.edges_valid.value = 0
    # Edges: 0->1, 0->2, 0->3, 1->3, 2->3
    set_edge(0, 0, 1)
    set_edge(1, 0, 2)
    set_edge(2, 0, 3)
    set_edge(3, 1, 3)
    set_edge(4, 2, 3)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    # Expected: 2
    # Public message from 0: reaches 0, 3 (stops at 1, 2). But 1 and 2 are enemies, we must not reach them. 
    # Wait, problem says "ensure that no enemy spies receive the message". 
    # If I send public message from 0, it goes to 1 and 2. That's bad.
    # So I cannot send public from 0.
    # I must send private messages or messages from sources that don't reach enemies.
    # 0 is connected to enemies. So 0 cannot send public.
    # 1 and 2 are enemies. I don't message them.
    # 3 is safe. I must message 3? Or 0 private?
    # Let's re-read. "ensure that no enemy spies receive the message".
    # If I message 0 private -> 0 is covered. 
    # 3 is not covered. I must message 3 private (or public, but no outgoing edges).
    # Total 2.
    if result != 2:
        raise TestFailure(f"Test Case 3 Failed: Expected 2, got {result}")
        
    cocotb.log.info("Test Case 3 Passed")
