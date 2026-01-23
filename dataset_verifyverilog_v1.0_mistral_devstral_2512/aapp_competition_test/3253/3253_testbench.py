import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

INF = 0x7FFFFFFF
CLK_PERIOD_NS = 10

def is_value_defined(value):
    try: int(value); return True
    except: return False

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def compute_expected(S, states):
    costs = []
    for (D,C,F,U) in states:
        if C > F+U: cost=0
        elif C+U <= F: cost=INF
        else: cost = ((F+U-C)//2)+1
        costs.append(cost)
    total_del = sum(D for D,_,_,_ in states)
    req = (total_del//2)+1
    best = INF
    for mask in range(1<<len(states)):
        sum_del=0; sum_cost=0
        for i in range(len(states)):
            if mask&(1<<i):
                sum_del += states[i][0]; sum_cost += costs[i]
        if sum_del>=req and sum_cost<best: best=sum_cost
    return best

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_election(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (3, [(7,2401,3299,0),(6,2401,2399,0),(2,750,750,99)], 50),
        (3, [(7,100,200,200),(8,100,300,200),(9,100,400,200)], INF),
        (3, [(32,0,0,20),(32,0,0,20),(64,0,0,41)], 32),
        (1, [(5,100,50,0)], 0),
        (1, [(5,50,100,0)], INF),
    ]
    
    for idx,(S,states,expected) in enumerate(test_cases):
        dut._log.info(f"Test {idx+1}: S={S}, expected={'impossible' if expected==INF else expected}")
        for i in range(8):
            if i < S:
                D,C,F,U = states[i]
                if has_signal(dut,'D'): dut.D[i].value = D
                else: getattr(dut,f'D_{i}').value = D
                if has_signal(dut,'C'): dut.C[i].value = C
                else: getattr(dut,f'C_{i}').value = C
                if has_signal(dut,'F'): dut.F[i].value = F
                else: getattr(dut,f'F_{i}').value = F
                if has_signal(dut,'U'): dut.U[i].value = U
                else: getattr(dut,f'U_{i}').value = U
            else:
                if has_signal(dut,'D'): dut.D[i].value = 0
                else: getattr(dut,f'D_{i}').value = 0
                if has_signal(dut,'C'): dut.C[i].value = 0
                else: getattr(dut,f'C_{i}').value = 0
                if has_signal(dut,'F'): dut.F[i].value = 0
                else: getattr(dut,f'F_{i}').value = 0
                if has_signal(dut,'U'): dut.U[i].value = 0
                else: getattr(dut,f'U_{i}').value = 0
        if has_signal(dut,'S'): dut.S.value = S
        await Timer(10, units='ns')
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        for _ in range(10000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value)==1:
                break
        else:
            raise TestFailure(f"Timeout test {idx+1}")
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined test {idx+1}")
        result = int(dut.result.value)
        if expected == INF:
            if result != INF:
                raise TestFailure(f"Test {idx+1}: expected impossible, got {result}")
        else:
            if result != expected:
                raise TestFailure(f"Test {idx+1}: expected {expected}, got {result}")
        dut._log.info(f"Test {idx+1}: PASS")
    dut._log.info("All tests passed")