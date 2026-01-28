import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MAX_EMP = 10
CLK_NS = 10
TIMEOUT_CYCLES = 5000

# Helpers
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'query_start'): dut.query_start.value = 0
    if has_signal(dut, 'data_in_valid'): dut.data_in_valid.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, signal_name='done'):
    for _ in range(TIMEOUT_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(getattr(dut, signal_name).value) and int(getattr(dut, signal_name).value) == 1:
            return
    raise TestFailure(f"Timeout waiting for {signal_name}")

async def send_input(dut, employees):
    # employees: list of tuples (id, salary, height)
    dut.data_in_valid.value = 1
    for emp in employees:
        # Send ID
        dut.data_bus.value = emp[0]
        await RisingEdge(dut.clk)
        # Send Salary
        dut.data_bus.value = emp[1]
        await RisingEdge(dut.clk)
        # Send Height
        dut.data_bus.value = emp[2]
        await RisingEdge(dut.clk)
    
    # End of Input
    dut.data_bus.value = 3 # Type 3 for end
    await RisingEdge(dut.clk)
    dut.data_in_valid.value = 0
    
    # Wait for processing
    await wait_for_done(dut, 'done')

async def query_employee(dut, emp_id):
    dut.query_id.value = emp_id
    dut.query_start.value = 1
    await RisingEdge(dut.clk)
    dut.query_start.value = 0
    await wait_for_done(dut, 'result_valid')
    boss = int(dut.result_boss.value)
    subs = int(dut.result_sub_count.value)
    return boss, subs

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_hierarchy(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Data (Scaled down for HDL)
    # ID, Salary, Height
    # Sort by Salary: 123456(14323), 123457(15221), 123458(41412)
    # 123456: H=1700000
    # 123457: H=1800000
    # 123458: H=1900000 (Chair)
    
    test_cases = [
        {
            "employees": [
                (123456, 14323, 1700000),
                (123458, 41412, 1900000),
                (123457, 15221, 1800000)
            ],
            "queries": [
                (123456, 123457, 0),  # Boss 123457, 0 subs
                (123458, 0, 2),        # Boss 0 (Chair), 2 subs
                (123457, 123458, 1)    # Boss 123458, 1 sub
            ]
        },
        {
            "employees": [
                (200002, 12234, 1832001),
                (200003, 15002, 1745201),
                (200004, 18745, 1883410),
                (200001, 24834, 1921313)
            ],
            "queries": [
                (200004, 200001, 2),
                (200002, 200004, 0),
                (200003, 200004, 0),
                (200001, 0, 3)
            ]
        }
    ]

    for tc_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {tc_idx + 1}")
        
        # Send Inputs
        await send_input(dut, tc["employees"])
        
        # Run Queries
        for q_id, exp_boss, exp_subs in tc["queries"]:
            cocotb.log.info(f"Query ID {q_id}")
            boss, subs = await query_employee(dut, q_id)
            if boss != exp_boss or subs != exp_subs:
                raise TestFailure(f"ID {q_id}: Expected Boss {exp_boss} Subs {exp_subs}, Got Boss {boss} Subs {subs}")

    cocotb.log.info("All tests passed!")