import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=3000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_exploding_worms(dut):
    # Setup
    dut.rst_n.value = 1
    dut.start.value = 0
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Helper to set input arrays
    async def set_inputs(x_vals, r_vals):
        # x_vals and r_vals are lists of 16 tuples (x, r)
        # We expect dut to have cans_x[15:0] and cans_r[15:0]
        for i in range(16):
            # x is signed 16-bit
            x = x_vals[i]
            x_bits = to_signed(int(x), 16) & 0xFFFF
            if has_signal(dut, f'cans_x_{i}'):
                getattr(dut, f'cans_x_{i}').value = x_bits
            elif has_signal(dut, 'cans_x'):
                dut.cans_x[i].value = x_bits
            
            # r is unsigned 16-bit
            r = r_vals[i]
            r_bits = int(r) & 0xFFFF
            if has_signal(dut, f'cans_r_{i}'):
                getattr(dut, f'cans_r_{i}').value = r_bits
            elif has_signal(dut, 'cans_r'):
                dut.cans_r[i].value = r_bits

    # Helper to read results
    async def get_results():
        res = []
        for i in range(16):
            if has_signal(dut, f'results_{i}'):
                val = int(getattr(dut, f'results_{i}').value)
            elif has_signal(dut, 'results'):
                val = int(dut.results[i].value)
            else:
                raise TestFailure("No results signal found")
            res.append(val)
        return res

    # Test Cases
    # Case 1: Simple chain
    # Cans: (4, 3), (-10, 9), (-2, 3)
    # Sorted: -10 (r9), -2 (r3), 4 (r3)
    # Distances: -10 to -2 = 8 (<=9, triggers), -2 to 4 = 6 (>3, no), -10 to 4 = 14 (>9, no)
    # If shot -10: triggers -2 -> stops. Count 2.
    # If shot -2: triggers 4? 6 > 3. No. Count 1.
    # If shot 4: triggers nothing. Count 1.
    # But wait, sample output is "1 2 1".
    # Input order: 4 3, -10 9, -2 3.
    # If shot 1st can (4,3): explodes 4. Count 1.
    # If shot 2nd can (-10,9): explodes -10, triggers -2 (dist 8 <= 9). Does -2 trigger 4? Dist 6 > 3. No. Count 2.
    # If shot 3rd can (-2,3): explodes -2, triggers 4 (dist 6 <= 3? No). Wait.
    # Let's re-read problem. "If another can is in the blast radius".
    # Can 1 (4, r3): Radius [1, 7]. Can 3 (-2) is at -2. Not in range.
    # Can 2 (-10, r9): Radius [-19, -1]. Can 3 (-2) is at -2. In range. Explodes Can 3.
    # Can 3 (-2, r3): Radius [-5, 1]. Can 1 (4) is at 4. Not in range.
    # So: Shot 1 -> 1 explosion. Shot 2 -> 2 explosions. Shot 3 -> 1 explosion.
    # Matches sample.

    # We need to feed 16 inputs. Padding with dummy cans.
    # Dummy cans: x=large, r=0 so they don't affect neighbors.
    
    x_in = [4, -10, -2] + [10000] * 13
    r_in = [3, 9, 3] + [0] * 13
    
    # Expected: [1, 2, 1, 0...]
    expected = [1, 2, 1] + [0] * 13

    await set_inputs(x_in, r_in)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    await wait_for_done(dut)

    results = await get_results()
    
    # Verify
    for i in range(3):
        if results[i] != expected[i]:
            raise TestFailure(f"Test 1 Index {i}: Expected {expected[i]}, got {results[i]}")
    
    for i in range(3, 16):
        if results[i] != 0:
             raise TestFailure(f"Test 1 Index {i}: Expected 0 (dummy), got {results[i]}")

    cocotb.log.info("Test 1 passed!")

    # Reset for next test
    await reset_dut(dut)

    # Case 2: Provided larger example
    # 12 cans
    raw_input = [
        (2, 2), (7, 7), (10, 1), (19, 3), (23, 12), (29, 8),
        (33, 1), (35, 17), (39, 2), (40, 1), (46, 11), (52, 3)
    ]
    
    # Sort them by x to analyze chain
    sorted_cans = sorted(raw_input, key=lambda p: p[0])
    # Indices in sorted order:
    # 0: (2,2)
    # 1: (7,7)
    # 2: (10,1)
    # 3: (19,3)
    # 4: (23,12)
    # 5: (29,8)
    # 6: (33,1)
    # 7: (35,17)
    # 8: (39,2)
    # 9: (40,1)
    # 10: (46,11)
    # 11: (52,3)

    # Let's trace logic for index 4 (23, 12) -> output says 9 (index 4 is 5th number -> 9)
    # Output string: "1 3 1 1 9 9 1 9 2 2 9 1"
    # Indexes 0-11.
    # Index 4 (val 9): x=23, r=12. Range [11, 35].
    # Hits: 19 (yes), 29 (yes), 33 (yes), 35 (yes).
    # 19 (r=3) -> [16,22]. Hits 23? No.
    # 29 (r=8) -> [21,37]. Hits 23 (yes), 33 (yes), 35 (yes).
    # 33 (r=1) -> [32,34]. Hits 35? No.
    # 35 (r=17) -> [18,52]. Hits ALL remaining.
    # Chain: 23 -> 19, 29, 33, 35.
    # 35 -> 2, 7, 10, 19, 23, 29, 33, 39, 40, 46 (and 52 is 52 > 52? 35+17=52. x=52 is included)
    # 52 is included. 35 hits 52 (dist 17 <= 17).
    # 52 hits nothing (r=3, max 55). 55 < 46? No.
    # 46 (r=11) -> [35, 57]. Hits 52.
    # Let's count unique cans from 23:
    # 23, 19, 29, 33, 35.
    # 35 triggers: 2, 7, 10, 19 (already), 23 (already), 29 (already), 33 (already), 39, 40, 46, 52.
    # Total unique: 23, 19, 29, 33, 35, 2, 7, 10, 39, 40, 46, 52.
    # That's 12 cans.
    # Wait, output says 9.
    # Re-read problem: "When a can explodes, if another can is in the blast radius, then that can will also explode"
    # Maybe order matters? No, process continues until stop.
    # Let's re-verify output string: "1 3 1 1 9 9 1 9 2 2 9 1"
    # Output Index 4 is 5th value = 9.
    # Let's look at 35 (r=17). Range [18, 52].
    # Cans: 2, 7, 10, 19, 23, 29, 33, 35, 39, 40, 46, 52.
    # 35 hits 19, 23, 29, 33, 39, 40, 46, 52. (8 cans + itself = 9)
    # Ah, 35 is at 35. 
    # 35 to 2 (dist 33) > 17. No.
    # 35 to 7 (dist 28) > 17. No.
    # 35 to 10 (dist 25) > 17. No.
    # 35 hits: 19 (dist 16), 23 (dist 12), 29 (dist 6), 33 (dist 2).
    # 39 (dist 4), 40 (dist 5), 46 (dist 11), 52 (dist 17).
    # Total 8 neighbors + 1 self = 9. Correct.
    
    # Back to index 4 (23, 12).
    # 23 hits: 19, 29, 33, 35.
    # 19 hits nothing new (range 16-22). 
    # 29 hits: 33, 35, 39, 40.
    # 33 hits nothing new (range 32-34).
    # 35 hits: 19, 23, 29, 33, 39, 40, 46, 52.
    # Total unique: 23, 19, 29, 33, 35, 39, 40, 46, 52.
    # That's 9 cans. Matches output.

    # Prepare inputs for Module (Original Order)
    x_full = [p[0] for p in raw_input]
    r_full = [p[1] for p in raw_input]
    # Pad to 16
    x_full += [100000] * 4
    r_full += [0] * 4

    expected_out = [1, 3, 1, 1, 9, 9, 1, 9, 2, 2, 9, 1] + [0] * 4

    await set_inputs(x_full, r_full)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    await wait_for_done(dut)

    results = await get_results()

    for i in range(16):
        if results[i] != expected_out[i]:
             raise TestFailure(f"Test 2 Index {i}: Expected {expected_out[i]}, got {results[i]}")

    cocotb.log.info("Test 2 passed!")
