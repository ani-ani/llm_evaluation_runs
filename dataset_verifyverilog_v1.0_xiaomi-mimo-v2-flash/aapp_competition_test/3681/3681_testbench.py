import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_params(params, bits=4, num_params=10):
    packed = 0
    for i in range(num_params):
        val = params[i] if i < len(params) else 0
        packed |= (val & ((1<<bits)-1)) << (i*bits)
    return packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_teacher_reassignment(dut):
    # Scale parameters
    N, M, Q = 16, 16, 16
    CLK_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test Case 1: Sample Input 1
    # Query sequence: Q=5
    # 0: type=1, d=3, x=4
    # 1: type=0, K=2, x=2, p=[3,2]
    # 2: type=1, d=3, x=2
    # 3: type=1, d=2, x=4
    # 4: type=1, d=1, x=4
    
    queries = [
        {'type': 1, 'x': 4, 'd': 3},     # Q1
        {'type': 0, 'x': 2, 'K': 2, 'p': [3,2]},  # Q2
        {'type': 1, 'x': 2, 'd': 3},     # Q3
        {'type': 1, 'x': 4, 'd': 2},     # Q4
        {'type': 1, 'x': 4, 'd': 1},     # Q5
    ]
    expected = [3, 2, 3, 1]
    
    # Prepare arrays for DUT
    q_type = [0]*Q
    q_x = [0]*Q
    q_k_or_d = [0]*Q
    q_params = [0]*Q
    
    for i, q in enumerate(queries):
        q_type[i] = q['type']
        q_x[i] = q['x']
        if q['type'] == 0:
            q_k_or_d[i] = q['K']
            q_params[i] = pack_params(q['p'])
        else:
            q_k_or_d[i] = q['d']
            q_params[i] = 0
    
    # Write to DUT (individual assignments per CRITICAL RULES)
    for i in range(Q):
        dut.q_type[i].value = q_type[i]
        dut.q_x[i].value = clamp_to_width(q_x[i], 4)
        dut.q_k_or_d[i].value = clamp_to_width(q_k_or_d[i], 4)
        dut.q_params[i].value = q_params[i]
    
    # Start processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 1000
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    # Verify results
    result_found = 0
    for i in range(Q):
        if queries[i]['type'] == 1:
            result_val = int(dut.result[i].value)
            exp = expected[result_found]
            if result_val != exp:
                raise TestFailure(f"Query {i}: Expected {exp}, got {result_val}")
            result_found += 1
    
    cocotb.log.info(f"Test 1 passed: {result_found} queries answered correctly")
    
    # Test Case 2: Sample Input 2
    # Reset and run second test
    await reset_dut(dut)
    
    queries2 = [
        {'type': 1, 'x': 4, 'd': 3},     # Q1
        {'type': 0, 'x': 2, 'K': 2, 'p': [3,2]},  # Q2
        {'type': 1, 'x': 2, 'd': 3},     # Q3
        {'type': 0, 'x': 3, 'K': 3, 'p': [3,1,2]},  # Q4
        {'type': 1, 'x': 4, 'd': 2},     # Q5
        {'type': 1, 'x': 4, 'd': 1},     # Q6
    ]
    expected2 = [3, 2, 2, 3]
    
    q_type = [0]*Q
    q_x = [0]*Q
    q_k_or_d = [0]*Q
    q_params = [0]*Q
    
    for i, q in enumerate(queries2):
        q_type[i] = q['type']
        q_x[i] = q['x']
        if q['type'] == 0:
            q_k_or_d[i] = q['K']
            q_params[i] = pack_params(q['p'])
        else:
            q_k_or_d[i] = q['d']
            q_params[i] = 0
    
    for i in range(Q):
        dut.q_type[i].value = q_type[i]
        dut.q_x[i].value = clamp_to_width(q_x[i], 4)
        dut.q_k_or_d[i].value = clamp_to_width(q_k_or_d[i], 4)
        dut.q_params[i].value = q_params[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    max_cycles = 1000
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    result_found = 0
    for i in range(Q):
        if queries2[i]['type'] == 1:
            result_val = int(dut.result[i].value)
            exp = expected2[result_found]
            if result_val != exp:
                raise TestFailure(f"Query {i}: Expected {exp}, got {result_val}")
            result_found += 1
    
    cocotb.log.info(f"Test 2 passed: {result_found} queries answered correctly")
    
    # Test Case 3: Edge cases
    # No reassignments, just queries
    await reset_dut(dut)
    
    queries3 = [
        {'type': 1, 'x': 1, 'd': 1},
        {'type': 1, 'x': 10, 'd': 5},
        {'type': 1, 'x': 16, 'd': 16},
    ]
    expected3 = [1, 5, 16]
    
    q_type = [0]*Q
    q_x = [0]*Q
    q_k_or_d = [0]*Q
    q_params = [0]*Q
    
    for i, q in enumerate(queries3):
        q_type[i] = q['type']
        q_x[i] = q['x']
        q_k_or_d[i] = q['d']
        q_params[i] = 0
    
    for i in range(Q):
        dut.q_type[i].value = q_type[i]
        dut.q_x[i].value = clamp_to_width(q_x[i], 4)
        dut.q_k_or_d[i].value = clamp_to_width(q_k_or_d[i], 4)
        dut.q_params[i].value = q_params[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    max_cycles = 1000
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    result_found = 0
    for i in range(Q):
        if queries3[i]['type'] == 1:
            result_val = int(dut.result[i].value)
            exp = expected3[result_found]
            if result_val != exp:
                raise TestFailure(f"Query {i}: Expected {exp}, got {result_val}")
            result_found += 1
    
    cocotb.log.info(f"Test 3 passed: {result_found} queries answered correctly")