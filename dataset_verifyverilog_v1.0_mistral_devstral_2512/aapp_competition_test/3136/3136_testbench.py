import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# CONFIGURATION
MAX_N = 4
MAX_S = 4
MAX_T = 4
MAX_M = 6
DATA_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# HELPER FUNCTIONS
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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ARRAY WRITE HELPERS
async def assign_employees(dut, values):
    for i in range(MAX_S):
        port_name = f'emp_loc_{i}'
        if has_signal(dut, port_name):
            if i < len(values):
                getattr(dut, port_name).value = clamp_to_width(values[i], 4)
            else:
                getattr(dut, port_name).value = 0
        else:
            raise TestFailure(f'Signal {port_name} not found')

async def assign_clients(dut, values):
    for i in range(MAX_T):
        port_name = f'cli_loc_{i}'
        if has_signal(dut, port_name):
            if i < len(values):
                getattr(dut, port_name).value = clamp_to_width(values[i], 4)
            else:
                getattr(dut, port_name).value = 0
        else:
            raise TestFailure(f'Signal {port_name} not found')

async def assign_edges(dut, edges):
    for i in range(MAX_M):
        u_name = f'edge_u_{i}'
        v_name = f'edge_v_{i}'
        d_name = f'edge_d_{i}'
        if has_signal(dut, u_name) and has_signal(dut, v_name) and has_signal(dut, d_name):
            if i < len(edges):
                u, v, d = edges[i]
                getattr(dut, u_name).value = clamp_to_width(u, 4)
                getattr(dut, v_name).value = clamp_to_width(v, 4)
                getattr(dut, d_name).value = clamp_to_width(d, DATA_WIDTH)
            else:
                getattr(dut, u_name).value = 0
                getattr(dut, v_name).value = 0
                getattr(dut, d_name).value = 0
        else:
            raise TestFailure(f'Signal {u_name} or {v_name} or {d_name} not found')

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

# PYTHON REFERENCE IMPLEMENTATION
def compute_expected(n, m, s, t, a, b, employees, clients, edges):
    INF = 10**12
    dist = [[INF]*n for _ in range(n)]
    for i in range(n):
        dist[i][i] = 0
    for u, v, d in edges:
        u0 = u-1
        v0 = v-1
        if d < dist[u0][v0]:
            dist[u0][v0] = d
            dist[v0][u0] = d
    for k in range(n):
        for i in range(n):
            if dist[i][k] == INF:
                continue
            for j in range(n):
                if dist[k][j] == INF:
                    continue
                if dist[i][k] + dist[k][j] < dist[i][j]:
                    dist[i][j] = dist[i][k] + dist[k][j]
    a0 = a-1
    b0 = b-1
    cost = [[0]*t for _ in range(s)]
    for i in range(s):
        e0 = employees[i]-1
        dA_e = dist[a0][e0]
        dB_e = dist[b0][e0]
        for j in range(t):
            c0 = clients[j]-1
            dA_c = dist[a0][c0]
            dB_c = dist[b0][c0]
            cost[i][j] = min(dA_e + dA_c, dB_e + dB_c)
    dp = [[INF]*(1<<s) for _ in range(t+1)]
    dp[0][0] = 0
    for j in range(t):
        for mask in range(1<<s):
            if dp[j][mask] == INF:
                continue
            for i in range(s):
                if not (mask & (1<<i)):
                    new_mask = mask | (1<<i)
                    new_cost = dp[j][mask] + cost[i][j]
                    if new_cost < dp[j+1][new_mask]:
                        dp[j+1][new_mask] = new_cost
    ans = INF
    for mask in range(1<<s):
        if bin(mask).count('1') == t:
            if dp[t][mask] < ans:
                ans = dp[t][mask]
    return ans

# MAIN TEST
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_shipping_optimizer(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases data
    test_cases = [
        {
            'n': 4, 'm': 4, 's': 2, 't': 2,
            'a': 1, 'b': 2,
            'employees': [3, 4],
            'clients': [3, 4],
            'edges': [(1,2,2), (1,3,1), (1,4,1), (2,4,2)]
        },
        {
            'n': 3, 'm': 3, 's': 2, 't': 2,
            'a': 1, 'b': 2,
            'employees': [2, 3],
            'clients': [2, 3],
            'edges': [(1,2,5), (1,3,1), (2,3,2)]
        },
        {
            'n': 2, 'm': 1, 's': 1, 't': 1,
            'a': 2, 'b': 2,
            'employees': [1],
            'clients': [1],
            'edges': [(1,2,100)]
        }
    ]
    
    passed = 0
    failed = 0
    
    for idx, tc in enumerate(test_cases):
        cocotb.log.info(f'Test case {idx+1}: n={tc["n"]}, m={tc["m"]}, s={tc["s"]}, t={tc["t"]}')
        
        # Compute expected
        expected = compute_expected(
            tc['n'], tc['m'], tc['s'], tc['t'],
            tc['a'], tc['b'],
            tc['employees'], tc['clients'], tc['edges']
        )
        cocotb.log.info(f'Expected: {expected}')
        
        # Set inputs
        dut.n.value = tc['n']
        dut.m.value = tc['m']
        dut.s.value = tc['s']
        dut.t.value = tc['t']
        dut.a.value = tc['a']
        dut.b.value = tc['b']
        
        # Assign arrays
        await assign_employees(dut, tc['employees'])
        await assign_clients(dut, tc['clients'])
        await assign_edges(dut, tc['edges'])
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.total_distance.value):
            raise TestFailure(f'Result is undefined (X/Z)')
        
        result = int(dut.total_distance.value)
        
        if result == expected:
            cocotb.log.info(f'PASS: result = {result}')
            passed += 1
        else:
            cocotb.log.error(f'FAIL: expected {expected}, got {result}')
            failed += 1
    
    cocotb.log.info('='*50)
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')