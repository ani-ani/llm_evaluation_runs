import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
MAX_STUDENTS = 8
MAX_BUGS = 8
DATA_WIDTH = 8
COST_WIDTH = 16
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bug_fix_scheduler(dut):
    """Test the bug fix scheduler module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (bugs, students, costs, max_cost, should_work, description)
    test_cases = [
        (
            [1, 3, 1, 2],  # bugs
            [2, 1, 3],      # student abilities
            [4, 3, 6],      # costs
            9,              # max_cost
            True,           # should work
            "Sample 1: 3 students, 4 bugs, budget 9"
        ),
        (
            [2, 3, 1, 2],
            [2, 1, 3],
            [4, 3, 6],
            10,
            True,
            "Sample 2: budget 10"
        ),
        (
            [2, 3, 1, 2],
            [2, 1, 3],
            [4, 3, 6],
            9,
            True,
            "Sample 3: tight budget 9"
        ),
        (
            [1, 3, 1, 2],
            [2, 1, 3],
            [5, 3, 6],
            5,
            False,
            "Sample 4: budget too low"
        ),
        (
            [1, 1, 1, 1],
            [2, 2, 2, 2],
            [1, 2, 3, 4],
            5,
            True,
            "All bugs same complexity"
        ),
        (
            [1, 2, 3],
            [3],
            [10],
            10,
            True,
            "Single student"
        ),
        (
            [8, 1],
            [5, 8],
            [10, 5],
            5,
            True,
            "High complexity bug"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (bugs, students, costs, max_cost, should_work, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx+1}: {desc}")
        cocotb.log.info(f"  Bugs: {bugs}, Students: {students}, Costs: {costs}, Max Cost: {max_cost}")
        
        try:
            # Pad inputs
            bugs_padded = bugs + [0] * (MAX_BUGS - len(bugs))
            students_padded = students + [0] * (MAX_STUDENTS - len(students))
            costs_padded = costs + [0] * (MAX_STUDENTS - len(costs))
            
            # Write inputs
            await write_array(dut, 'bug_complexity', bugs_padded, DATA_WIDTH)
            await write_array(dut, 'student_ability', students_padded, DATA_WIDTH)
            await write_array(dut, 'student_cost', costs_padded, COST_WIDTH)
            
            # Set other inputs
            dut.num_bugs.value = len(bugs)
            dut.num_students.value = len(students)
            dut.max_cost.value = max_cost
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal undefined")
            
            valid_result = int(dut.valid.value)
            
            if valid_result != should_work:
                raise TestFailure(f"Valid mismatch: expected {should_work}, got {valid_result}")
            
            if valid_result:
                # Read assignment
                assignment = await read_array(dut, 'assignment', MAX_BUGS)
                days = int(dut.days_needed.value)
                cost = int(dut.total_cost.value)
                
                cocotb.log.info(f"  Result: days={days}, cost={cost}")
                
                # Verify all bugs assigned
                for i in range(len(bugs)):
                    if assignment[i] == 0:
                        raise TestFailure(f"Bug {i} not assigned")
                    student_idx = assignment[i] - 1
                    if student_idx >= len(students):
                        raise TestFailure(f"Bug {i} assigned to invalid student {assignment[i]}")
                    if students[student_idx] < bugs[i]:
                        raise TestFailure(f"Student {assignment[i]} cannot fix bug {i}")
                
                # Check cost constraint
                if cost > max_cost:
                    raise TestFailure(f"Cost {cost} exceeds budget {max_cost}")
                
                cocotb.log.info(f"  PASS")
                passed += 1
            else:
                cocotb.log.info(f"  PASS (correctly impossible)")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")