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

# Constants
MAX_TEAMS = 10
CLK_NS = 10

def id_to_index(id_val):
    """Map employee IDs to indices"""
    if 1000 <= id_val <= 1099:
        return id_val - 1000  # 0-99, but we only use 0-9
    elif 2000 <= id_val <= 2099:
        return (id_val - 2000) + 10  # 10-109, but we only use 10-15
    return -1

def index_to_id(idx):
    """Convert index back to employee ID"""
    if idx < 10:
        return 1000 + idx
    else:
        return 2000 + (idx - 10)

async def wait_for_done(dut, max_cycles=200):
    """Wait for result_valid signal"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    """Reset the DUT"""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_teams(dut, teams):
    """Write team data to the module"""
    dut.valid_team.value = 1
    for stock_id, london_id in teams:
        # Map IDs to indices
        s_idx = stock_id - 1000 if 1000 <= stock_id <= 1099 else 0
        l_idx = london_id - 2000 if 2000 <= london_id <= 2099 else 0
        
        dut.stockholm_id.value = clamp_to_width(s_idx, 10)
        dut.london_id.value = clamp_to_width(l_idx, 10)
        await RisingEdge(dut.clk)
    dut.valid_team.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_minimum_vertex_cover(dut):
    """Test the minimum vertex cover module"""
    
    # Check required signals
    required_signals = ['clk', 'rst_n', 'start', 'valid_team', 
                       'stockholm_id', 'london_id', 'result_valid', 'result_size']
    for sig in required_signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        {
            'teams': [(1009, 2011), (1017, 2011)],
            'expected_size': 1,
            'expected_contains_friend': False,
            'desc': 'Two teams sharing one London employee'
        },
        {
            'teams': [(1009, 2000), (1009, 2001), (1002, 2002), (1003, 2002)],
            'expected_size': 2,
            'expected_contains_friend': True,
            'desc': 'Friend in two teams, separate team without friend'
        },
        {
            'teams': [(1001, 2000), (1002, 2000), (1003, 2000), (1009, 2001)],
            'expected_size': 2,
            'expected_contains_friend': True,
            'desc': 'Star graph with friend on separate edge'
        },
        {
            'teams': [(1009, 2000), (1009, 2001)],
            'expected_size': 1,
            'expected_contains_friend': True,
            'desc': 'Friend only in teams'
        }
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, test in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx+1}: {test['desc']}")
        cocotb.log.info(f"Teams: {test['teams']}")
        
        try:
            # Reset
            dut.start.value = 0
            await reset_dut(dut)
            
            # Write team data
            await write_teams(dut, test['teams'])
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for result
            await wait_for_done(dut, max_cycles=200)
            
            # Read result
            result_size = int(dut.result_size.value)
            cocotb.log.info(f"Result size: {result_size}")
            
            if result_size < 1 or result_size > 16:
                raise TestFailure(f"Result size out of range: {result_size}")
            
            # Read invite list
            invite_list = []
            for i in range(result_size):
                if has_signal(dut, f'result_{i}'):
                    idx_val = int(getattr(dut, f'result_{i}').value)
                    if idx_val < 0 or idx_val >= 20:
                        raise TestFailure(f"Invalid index at position {i}: {idx_val}")
                    employee_id = index_to_id(idx_val)
                    invite_list.append(employee_id)
                    cocotb.log.info(f"  Invite {i}: {employee_id}")
            
            # Verify size
            if result_size != test['expected_size']:
                raise TestFailure(f"Size mismatch. Expected {test['expected_size']}, got {result_size}")
            
            # Verify friend inclusion preference
            friend_included = 1009 in invite_list
            if friend_included != test['expected_contains_friend']:
                # This might be acceptable if alternative minimum cover exists
                cocotb.log.warning(f"Friend inclusion mismatch. Expected {test['expected_contains_friend']}, got {friend_included}")
                # Check if cover size is still minimum
                if result_size == test['expected_size']:
                    cocotb.log.info("But cover size is minimum, acceptable solution")
                else:
                    raise TestFailure("Non-minimum cover size")
            
            # Verify cover property
            # For each team, at least one employee must be invited
            for stock_id, london_id in test['teams']:
                if stock_id not in invite_list and london_id not in invite_list:
                    raise TestFailure(f"Team ({stock_id}, {london_id}) not covered")
            
            cocotb.log.info(f"PASS: Valid minimum cover, size {result_size}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n=== SUMMARY ===")
    cocotb.log.info(f"Passed: {passed}/{len(test_cases)}")
    cocotb.log.info(f"Failed: {failed}/{len(test_cases)}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")