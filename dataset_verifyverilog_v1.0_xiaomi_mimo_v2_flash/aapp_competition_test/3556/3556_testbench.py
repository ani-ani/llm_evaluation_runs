import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
MAX_EMPLOYEES = 4
ID_WIDTH = 20
SALARY_WIDTH = 24
HEIGHT_WIDTH = 24
CLK_PERIOD_NS = 10

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.query_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_ready(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.ready.value) and int(dut.ready.value) == 1:
            return
    raise TestFailure(f"Timeout: ready not asserted after {max_cycles} cycles")

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def write_employee(dut, idx, emp_id, salary, height):
    """Write a single employee data."""
    if has_signal(dut, f'id_{idx}'):
        getattr(dut, f'id_{idx}').value = clamp_to_width(emp_id, ID_WIDTH)
        getattr(dut, f'salary_{idx}').value = clamp_to_width(salary, SALARY_WIDTH)
        getattr(dut, f'height_{idx}').value = clamp_to_width(height, HEIGHT_WIDTH)

async def start_precomputation(dut, num_employees):
    """Start the precomputation phase."""
    dut.num_employees.value = num_employees
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def process_query(dut, query_id):
    """Process a single query and return results."""
    dut.query_id.value = query_id
    await RisingEdge(dut.clk)
    dut.query_valid.value = 1
    await RisingEdge(dut.clk)
    dut.query_valid.value = 0
    
    await wait_for_done(dut)
    await RisingEdge(dut.clk)  # Stabilize outputs
    
    # Read results
    if not is_value_defined(dut.boss_id.value) or not is_value_defined(dut.num_subordinates.value):
        raise TestFailure("Output signals undefined")
    
    boss = int(dut.boss_id.value)
    subs = int(dut.num_subordinates.value)
    
    return boss, subs

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tall_enterprises(dut):
    """Test the tall_enterprises module with multiple test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Test cases
    test_cases = [
        {
            'name': 'Sample 1: 3 employees',
            'num_employees': 3,
            'employees': [
                (123456, 14323, 1700000),
                (123458, 41412, 1900000),
                (123457, 15221, 1800000),
            ],
            'queries': [123456, 123458, 123457],
            'expected': [(123457, 0), (0, 2), (123458, 1)],
        },
        {
            'name': 'Sample 2: 4 employees',
            'num_employees': 4,
            'employees': [
                (200002, 12234, 1832001),
                (200003, 15002, 1745201),
                (200004, 18745, 1883410),
                (200001, 24834, 1921313),
            ],
            'queries': [200004, 200002, 200003, 200001],
            'expected': [(200001, 2), (200004, 0), (200004, 0), (0, 3)],
        },
        {
            'name': 'Edge: Single employee',
            'num_employees': 1,
            'employees': [(123456, 50000, 1800000)],
            'queries': [123456],
            'expected': [(0, 0)],
        },
    ]
    
    total_passed = 0
    total_failed = 0
    
    for tc in test_cases:
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test: {tc['name']}")
        dut._log.info(f"{'='*60}")
        
        # Reset
        await reset_dut(dut)
        
        # Write employee data
        for idx, (emp_id, salary, height) in enumerate(tc['employees']):
            await write_employee(dut, idx, emp_id, salary, height)
            dut._log.info(f"  Employee {idx}: ID={emp_id}, Salary={salary}, Height={height}")
        
        # Start precomputation
        await start_precomputation(dut, tc['num_employees'])
        
        # Wait for ready
        await wait_for_ready(dut)
        dut._log.info("  Precomputation complete")
        
        # Process queries
        for q_idx, query_id in enumerate(tc['queries']):
            dut._log.info(f"\n  Query {q_idx+1}: ID={query_id}")
            
            try:
                boss, subs = await process_query(dut, query_id)
                exp_boss, exp_subs = tc['expected'][q_idx]
                
                if boss == exp_boss and subs == exp_subs:
                    dut._log.info(f"    PASS: boss={boss}, subs={subs}")
                    total_passed += 1
                else:
                    dut._log.error(f"    FAIL: Expected ({exp_boss}, {exp_subs}), got ({boss}, {subs})")
                    total_failed += 1
            except TestFailure as e:
                dut._log.error(f"    FAIL: {e}")
                total_failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"FINAL RESULTS: {total_passed}/{total_passed+total_failed} tests passed")
    dut._log.info(f"{'='*60}")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} test(s) failed")