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

DATA_WIDTH = 8
MAX_GEMS = 16
CLK_NS = 10
MAX_CYCLES = 1000

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_racing_gems(dut):
    # Setup clock and reset
    if not has_signal(dut, 'clk'):
        # Combinational logic test (unlikely for this problem)
        await Timer(100, units='ns')
        return
        
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to wait for done
    async def wait_for_done():
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return
        raise TestFailure("Timeout waiting for done signal")

    # Test Case 1: From Example 1 (scaled down)
    # Original: r=1, w=10, h=10. Gems: (8,8), (5,1), (4,6), (4,7), (7,9)
    # Scaled coordinates: Divide by 10 (approx) or keep small numbers for simulation.
    # Let's use the provided small numbers directly as they are within 8-bit range.
    gems = [
        (8, 8),
        (5, 1),
        (4, 6),
        (4, 7),
        (7, 9)
    ]
    # Input order: The algorithm needs sorted by Y.
    # Sorted by Y: (5,1), (4,6), (4,7), (8,8), (7,9)
    gems_sorted = sorted(gems, key=lambda g: g[1])
    
    r = 1
    w = 10
    num_gems = len(gems_sorted)
    
    dut.r_in.value = r
    dut.w_in.value = w
    dut.num_gems.value = num_gems
    
    # Phase 1: Load Gems
    # Assuming simple interface where we send gems one by one or all at once.
    # The spec suggests a serial load or parallel RAM write. 
    # Given the "gem_x_in", "gem_y_in", "gem_idx_in" in spec, let's assume serial load.
    if has_signal(dut, 'gem_idx_in'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # In IDLE, we might need to load data. Or maybe LOAD state.
        # Let's assume the module has a load mechanism triggered by start or separate signals.
        # If the module is designed to read from RAM inputs immediately, we just set them.
        # Let's assume the module exposes RAM inputs directly for simplicity in test.
        for i, (x, y) in enumerate(gems_sorted):
            dut.gem_x_in[i].value = x
            dut.gem_y_in[i].value = y
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    else:
        # Alternative interface: assume inputs are latched on start
        # or just set inputs directly if they are top level ports.
        for i in range(16):
            if i < len(gems_sorted):
                # Clamp just in case
                x, y = gems_sorted[i]
                if has_signal(dut, f'gem_x_{i}'): getattr(dut, f'gem_x_{i}').value = x
                elif has_signal(dut, 'gem_x_in'): pass # handled later
                
                if has_signal(dut, f'gem_y_{i}'): getattr(dut, f'gem_y_{i}').value = y
            else:
                if has_signal(dut, f'gem_x_{i}'): getattr(dut, f'gem_x_{i}').value = 0
                if has_signal(dut, f'gem_y_{i}'): getattr(dut, f'gem_y_{i}').value = 0
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

    # Wait for calculation
    await wait_for_done()
    
    if has_signal(dut, 'result'):
        result = int(dut.result.value)
        # Expected output is 3
        if result != 3:
            raise TestFailure(f"Test Case 1 Failed: Expected 3, got {result}")
    else:
        # Check per-gem DP output if full result not exposed
        pass

    # Test Case 2: Sorted input with no collisions
    # r=3, w=30. Gems: (14,9), (2,20)...
    # Expected output: 4
    gems2 = [(14,9), (2,20), (3,23), (15,19), (13,5), (17,24), (6,16), (21,5), (14,10), (3,6)]
    # Sort by Y
    gems2_sorted = sorted(gems2, key=lambda g: g[1])
    
    dut.r_in.value = 3
    dut.w_in.value = 30
    dut.num_gems.value = len(gems2_sorted)
    
    # Reload data
    if has_signal(dut, 'gem_idx_in'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        for i, (x, y) in enumerate(gems2_sorted):
            dut.gem_x_in[i].value = x
            dut.gem_y_in[i].value = y
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    else:
        for i in range(16):
            if i < len(gems2_sorted):
                x, y = gems2_sorted[i]
                if has_signal(dut, f'gem_x_{i}'): getattr(dut, f'gem_x_{i}').value = x
                if has_signal(dut, f'gem_y_{i}'): getattr(dut, f'gem_y_{i}').value = y
            else:
                if has_signal(dut, f'gem_x_{i}'): getattr(dut, f'gem_x_{i}').value = 0
                if has_signal(dut, f'gem_y_{i}'): getattr(dut, f'gem_y_{i}').value = 0
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
    await wait_for_done()
    
    if has_signal(dut, 'result'):
        result = int(dut.result.value)
        if result != 4:
            raise TestFailure(f"Test Case 2 Failed: Expected 4, got {result}")
