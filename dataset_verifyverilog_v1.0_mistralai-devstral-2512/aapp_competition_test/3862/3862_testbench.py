import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants based on constraints
STATE_BITS = 11
DIST_BITS = 10
RESULT_BITS = 12
MAX_STATE = (1 << STATE_BITS) - 1
STATE_OFFSET = 1000  # To map -1000..1000 to 0..2000

# Helper functions
def is_value_defined(v):
    try: 
        int(v)
        return True
    except ValueError: 
        return False

def clamp_to_width(v, bits):
    v = int(v)
    if v < 0: v = 0
    max_val = (1 << bits) - 1
    return min(v, max_val)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): 
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Function to prepare the difference availability array
# We map concentration differences -1000..1000 to indices 0..2000
def prepare_diff_avail(a_list, target_n):
    diff_avail = 0
    diffs = set()
    for a in a_list:
        diff = a - target_n
        if -1000 <= diff <= 1000:
            idx = diff + STATE_OFFSET
            diff_avail |= (1 << idx)
            diffs.add(diff)
    return diff_avail, diffs

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_coke_mix(dut):
    # Setup clock if sequential
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational? Unlikely for BFS, but handle gracefully
        await Timer(100, units='ns')

    # Test cases
    test_cases = [
        (400, [100, 300, 450, 500], 2),
        (50, [100, 25], 3),
        (500, [1000, 5, 5], 199),
        (500, [1000], -1),
        (874, [873, 974, 875], 2),
        (999, [1, 1000], 999),
        (326, [684, 49, 373, 57, 747, 132, 441, 385, 640, 575, 567, 665, 323, 515, 527, 656, 232, 701], 3),
        (314, [160, 769, 201, 691, 358, 724, 248, 47, 420, 432, 667, 601, 596, 370, 469], 4),
        (0, [0], 1),
        (0, [1000], -1),
        (345, [497, 135, 21, 199, 873], 5),
        (641, [807, 1000, 98, 794, 536, 845, 407, 331], 7),
        (852, [668, 1000, 1000, 1000, 1000, 1000, 1000, 639, 213, 1000], 10),
        (710, [854, 734, 63, 921, 921, 187, 978], 5),
        (134, [505, 10, 1, 363, 344, 162], 4),
        (951, [706, 1000, 987, 974, 974, 706, 792, 792, 974, 1000, 1000, 987, 974, 953, 953], 6),
        (834, [921, 995, 1000, 285, 1000, 166, 1000, 999, 991, 983], 10),
        (917, [999, 998, 1000, 997, 1000, 998, 78, 991, 964, 985, 987, 78, 985, 999, 83, 987, 1000, 999, 999, 78, 83], 12),
        (971, [692, 1000, 1000, 997, 1000, 691, 996, 691, 1000, 1000, 1000, 692, 1000, 997, 1000], 11),
        (1000, [536, 107, 113, 397, 613, 1, 535, 652, 730, 137, 239, 538, 764, 431, 613, 273], 10),
        (998, [1, 1000], 999),
        (998, [1, 999, 1000], 500),
        (998, [1, 2, 999, 1000], 499),
        (500, [1000, 2], 499),
        (508, [0, 998, 997, 1, 1, 2, 997, 1, 997, 1000, 0, 3, 3, 2, 4], 53),
        (492, [706, 4], 351),
        (672, [4, 6, 1000, 995, 997], 46),
        (410, [998, 8, 990, 990], 54),
        (499, [1000, 2], 998),
        (995, [996, 997, 998, 999, 1000], -1),
        (500, [499, 1000, 300], 7),
        (499, [0, 1000], 1000),
        (1000, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], -1),
        (501, [1, 1000], 999)
    ]

    passed = 0
    failed = 0

    for i, (target, concentrations, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Target {target}, {len(concentrations)} types, Expect {expected}")
        
        # Prepare inputs
        diff_avail, diffs = prepare_diff_avail(concentrations, target)
        
        # Convert diff_avail to array of 32-bit chunks if needed (assuming 2048 bits)
        # Since Verilog handles logic vectors, we might split if the input is wide
        # Assuming the module has a wide input or we iterate setting bits. 
        # For simplicity in this testbench, let's assume the DUT has a 2048-bit input or multiple 32-bit inputs.
        # Given the constraint of Verilog, we will map to 'diff_0', 'diff_1' etc or a single large logic.
        # Let's assume we have a 2048-bit array input named 'diff_i' or similar, or we use the helper function to set bits individually if it's an array.
        # But usually for such wide inputs in Verilog tests, it's a vector.
        # If 'diff' is a 2048-bit vector:
        # We need to assign it.
        
        # Check for 'diff' signal existence
        if has_signal(dut, 'diff'):
            # Assign the vector
            # Python int to binary string or just integer assignment
            dut.diff.value = diff_avail
        elif has_signal(dut, 'diff_0'): # Split input
             # Split into 32-bit chunks
             for k in range(64): # 2048 / 32 = 64
                 chunk = (diff_avail >> (k*32)) & 0xFFFFFFFF
                 sig_name = f'diff_{k}'
                 if has_signal(dut, sig_name):
                     getattr(dut, sig_name).value = chunk
        elif has_signal(dut, 'diff_arr'): # Array of logic
             # We need to iterate if it's an array of wires
             # This is rare for wide inputs but handled by spec
             for idx in range(2048):
                 bit = (diff_avail >> idx) & 1
                 dut.diff_arr[idx].value = bit

        if has_signal(dut, 'target_n'):
            dut.target_n.value = clamp_to_width(target + STATE_OFFSET, STATE_BITS)
        
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')

        try:
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Test {i+1}: Result undefined")
            
            result = int(dut.result.value)
            
            # Check validity signal if exists
            if has_signal(dut, 'valid'):
                is_valid = int(dut.valid.value) == 1
                if expected == -1:
                    if is_valid:
                        raise TestFailure(f"Expected invalid, but got valid with result {result}")
                else:
                    if not is_valid:
                         raise TestFailure(f"Expected valid result {expected}, but got invalid")
                    if result != expected:
                        raise TestFailure(f"Expected {expected}, got {result}")
            else:
                # Fallback logic if no valid signal
                if result != expected:
                     raise TestFailure(f"Expected {expected}, got {result}")

            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
