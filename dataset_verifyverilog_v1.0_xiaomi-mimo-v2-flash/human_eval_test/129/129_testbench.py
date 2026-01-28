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

# Helper to pack grid values (row-major) into 64-bit integer
def pack_grid(grid_2d, size):
    # grid_2d is list of lists
    # Flatten and pack into 4-bit chunks (values 1-16)
    flat = []
    for r in range(size):
        for c in range(size):
            flat.append(grid_2d[r][c])
    packed = 0
    for i, val in enumerate(flat):
        packed |= (val & 0xF) << (i * 4)
    return packed

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_minPath(dut):
    # Setup Clock
    clk_period = 10
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, clk_period, units='ns')
        clock.start()
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational logic assumed
        await Timer(10, units='ns')

    # Test cases (scaled down for Verilog constraints: max grid 4x4, max k 16)
    test_cases = [
        # grid, k, expected_path
        ([[1, 2, 3], [4, 5, 6], [7, 8, 9]], 3, [1, 2, 1]),  # 3x3 -> treated as 4x4 padded? No, logic should handle size.
        # Wait, spec says N>=2. Let's stick to 2x2 or 4x4 for simplicity in packing.
        # 3x3 is awkward for 64-bit packed (9 values). We'll skip 3x3 in HDL testbench or pad it.
        # Let's map 3x3 to 4x4 with high dummy values or just handle 2x2 and 4x4.
        # The prompt says "N=2 or 4" in analysis. I will only test valid N.
        
        ([[1, 2], [3, 4]], 4, [1, 2, 1, 2]),  # 2x2
        ([[1, 2], [3, 4]], 2, [1, 2]),
        ([[1, 3], [3, 2]], 4, [1, 3, 1, 3]), # 2x2
        ([[5, 9, 3], [4, 1, 6], [7, 8, 2]], 1, [1]), # 3x3 -> Skip or Pad
        
        # 4x4 cases from prompt
        ([[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]], 4, [1, 2, 1, 2]),
    ]

    passed = 0
    failed = 0

    for grid, k, expected in test_cases:
        size = len(grid)
        
        # Skip invalid sizes for this HDL implementation (must be 2 or 4)
        if size != 2 and size != 4:
            cocotb.log.info(f"Skipping test {size}x{size} (HDL supports 2x2 or 4x4)")
            continue

        cocotb.log.info(f"Testing {size}x{size} grid, k={k}, expected={expected}")
        
        # Prepare Inputs
        packed_grid = pack_grid(grid, size)
        
        if has_signal(dut, 'grid_data'):
            dut.grid_data.value = packed_grid
        
        if has_signal(dut, 'grid_size'):
            dut.grid_size.value = 1 if size == 4 else 0
            
        if has_signal(dut, 'k'):
            dut.k.value = k
            
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Wait for done/valid sequence
        # The module outputs the path sequentially with 'valid' pulse
        results = []
        
        # Wait for first valid or timeout
        max_cycles = 2000
        cycles = 0
        found_data = False
        
        # Check if 'busy' signal exists to wait for calculation start
        if has_signal(dut, 'busy'):
            while int(dut.busy.value) == 1 and cycles < max_cycles:
                await RisingEdge(dut.clk)
                cycles += 1
        
        # Now wait for valid output pulses
        # We expect k outputs
        while len(results) < k and cycles < max_cycles:
            await RisingEdge(dut.clk)
            cycles += 1
            
            if has_signal(dut, 'valid') and is_value_defined(dut.valid.value):
                if int(dut.valid.value) == 1:
                    val = int(dut.result.value)
                    results.append(val)
                    cocotb.log.info(f"Step {len(results)-1}: Got {val}")
            else:
                # If no valid signal, maybe done signals it? Check done
                if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                    if int(dut.done.value) == 1:
                        val = int(dut.result.value)
                        results.append(val)
                        # If done is only 1 cycle for the whole packet, we need a different mechanism.
                        # But the spec said "done: 1-cycle when valid".
                        # If it's a single pulse, we can't stream k values.
                        # The modified spec in the prompt description uses 'valid' for streaming.
                        # If 'done' is the only output, we have to assume 'result' holds the full path packed?
                        # Let's assume 'valid' is present as per the refined spec.
            
            # Fallback: if no valid/done, check if result changes (heuristic)
            # 
        
        # Verify
        if results == expected:
            cocotb.log.info("PASS")
            passed += 1
        else:
            cocotb.log.error(f"FAIL: Expected {expected}, got {results}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
