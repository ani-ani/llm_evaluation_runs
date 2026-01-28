import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_CLUBS = 4
MAX_RESIDENTS = 4
MAX_PARTIES = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS (from template)
# ============================================================================
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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_array(dut, array_name, values, element_width):
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            return True
        if is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
            return False
    raise TestFailure(f"Timeout: no valid or impossible after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAPPING FROM INDICES TO NAMES (for example test case)
# ============================================================================
resident_names = {0: "fred", 1: "john", 2: "mary", 3: "ruth"}
party_names = {0: "dinosaur", 1: "rhinocerous", 2: "platypus"}
club_names = {0: "jets", 1: "jetsons", 2: "rockets"}

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_council(dut):
    """Test the council assignment module with multiple test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (num_clubs, num_residents, num_parties, resident_party_list, club_size_list, club_residents_flat, description, expect_impossible)
    # Note: club_residents_flat is a list of length MAX_CLUBS * MAX_RESIDENTS, with values 0-15 or 0xF for invalid.
    test_cases = [
        # Test case 1: Example from problem (3 clubs, 4 residents, 3 parties)
        (
            3, 4, 3,
            [0, 1, 1, 2],  # resident_party: fred(0), john(1), mary(1), ruth(2)
            [2, 2, 3],     # club_size: jets=2, jetsons=2, rockets=3
            # club_residents flattened: for each club, 4 entries (MAX_RESIDENTS=4)
            # club0 (jets): residents 0,1 -> positions 0,1; others 0xF
            [0, 1, 0xF, 0xF,
             # club1 (jetsons): residents 0,2 -> positions 0,2; others 0xF
             0, 0xF, 2, 0xF,
             # club2 (rockets): residents 1,2,3 -> positions 0,1,2; others 0xF
             1, 2, 3, 0xF],
            "Example with 3 clubs, should be possible",
            False
        ),
        # Test case 2: Impossible case (2 clubs, 2 residents, same party)
        (
            2, 2, 1,
            [0, 0],        # both residents same party
            [1, 1],        # each club has one resident
            # club0: resident0 at pos0
            [0, 0xF, 0xF, 0xF,
             # club1: resident1 at pos0
             1, 0xF, 0xF, 0xF],
            "Impossible case: 2 clubs, same party, threshold=1, need 2 reps -> impossible",
            True
        )
    ]
    
    for test_idx, (num_clubs, num_residents, num_parties, resident_party_list, club_size_list, club_residents_flat, description, expect_impossible) in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test {test_idx+1}: {description}")
        dut._log.info(f"{'='*60}")
        
        # Set scalar inputs
        dut.num_clubs.value = num_clubs
        dut.num_residents.value = num_residents
        dut.num_parties.value = num_parties
        
        # Set resident_party array
        for i, party in enumerate(resident_party_list):
            dut.resident_party[i].value = party
        
        # Set club_size array
        for i, size in enumerate(club_size_list):
            dut.club_size[i].value = size
        
        # Set club_residents flattened array
        for idx, val in enumerate(club_residents_flat):
            # Clamp to 4 bits (should be already)
            dut.club_residents[idx].value = val
        
        # Start computation
        await start_computation(dut)
        
        # Wait for completion
        result_valid = await wait_for_done(dut)
        
        if expect_impossible:
            if result_valid:
                raise TestFailure(f"Expected impossible but got valid assignment")
            else:
                dut._log.info("Correctly reported impossible")
        else:
            if not result_valid:
                raise TestFailure(f"Expected valid assignment but got impossible")
            else:
                # Read assignment array
                assignment = []
                for i in range(num_clubs):
                    if is_value_defined(dut.assignment[i].value):
                        assignment.append(int(dut.assignment[i].value))
                    else:
                        raise TestFailure(f"Assignment for club {i} is undefined")
                # Print assignment
                for club_idx in range(num_clubs):
                    resident_idx = assignment[club_idx]
                    resident_name = resident_names.get(resident_idx, f"resident_{resident_idx}")
                    club_name = club_names.get(club_idx, f"club_{club_idx}")
                    dut._log.info(f"{resident_name} {club_name}")
                # Also print a blank line between test cases as per problem statement
                if test_idx < len(test_cases)-1:
                    dut._log.info("")
        
        # Reset for next test case
        await reset_dut(dut)
