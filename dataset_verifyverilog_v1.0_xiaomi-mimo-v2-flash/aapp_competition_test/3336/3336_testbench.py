import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Solver for verification
def solve_py(students):
    # students: list of tuples (h, sex, music, sport)
    n = len(students)
    edges = []
    males = []
    females = []
    
    for i, s in enumerate(students):
        if s[1] == 'M': males.append((i, s))
        else: females.append((i, s))
        
    # Build adjacency for male index -> female index
    adj = [[] for _ in range(len(males))]
    for mi, m in enumerate(males):
        for fi, f in enumerate(females):
            # Check if they CAN be a couple (bad for excursion)
            h_diff = abs(m[1][0] - f[1][0])
            sex_diff = m[1][1] != f[1][1] # Always True here
            music_same = m[1][2] == f[1][2]
            sport_diff = m[1][3] != f[1][3]
            
            # Condition to add edge: They ARE a potential couple
            # i.e., Violate ALL 4 rules. 
            # Rules: h_diff > 40 (Good), same sex (Impossible here), music diff (Good), sport same (Good).
            # So potential couple if: h_diff <= 40, music same, sport diff.
            if h_diff <= 40 and music_same and sport_diff:
                adj[mi].append(fi)
    
    # Bipartite Matching
    match_r = [-1] * len(females)
    match_l = [-1] * len(males)
    
    def bpm(u, seen):
        for v in adj[u]:
            if not seen[v]:
                seen[v] = True
                if match_r[v] < 0 or bpm(match_r[v], seen):
                    match_r[v] = u
                    match_l[u] = v
                    return True
        return False
    
    matching = 0
    for u in range(len(males)):
        seen = [False] * len(females)
        if bpm(u, seen):
            matching += 1
            
    return n - matching

# Test Cases
TEST_CASES = [
    {
        "desc": "Sample 1: 4 students",
        "inp": [
            (35, 'M', 'classicism', 'programming'),
            (0, 'M', 'baroque', 'skiing'),
            (43, 'M', 'baroque', 'chess'),
            (30, 'F', 'baroque', 'soccer')
        ],
        "exp": 3
    },
    {
        "desc": "Sample 2: 8 students",
        "inp": [
            (27, 'M', 'romance', 'programming'),
            (194, 'F', 'baroque', 'programming'),
            (67, 'M', 'baroque', 'ping-pong'),
            (51, 'M', 'classicism', 'programming'),
            (80, 'M', 'classicism', 'Paintball'),
            (35, 'M', 'baroque', 'ping-pong'),
            (39, 'F', 'romance', 'ping-pong'),
            (110, 'M', 'romance', 'Paintball')
        ],
        "exp": 7
    }
]

# Encoding helpers
MUSIC_MAP = {"classicism":0, "baroque":1, "romance":2, "Paintball":3}
SPORT_MAP = {"programming":0, "skiing":1, "chess":2, "soccer":3, "ping-pong":4, "Paintball":5}

def encode(s, mapping):
    if s in mapping: return mapping[s]
    # Hash string to 3 bits for unknown strings
    h = 0
    for c in s: h = (h + ord(c)) & 7
    return h

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_excursion(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    passed = 0
    for tc in TEST_CASES:
        cocotb.log.info(f"Testing: {tc['desc']}")
        n = len(tc['inp'])
        
        # Assign inputs
        for i in range(16): # Max N
            if i < n:
                h, sex, music, sport = tc['inp'][i]
                dut.h[i].value = clamp_to_width(h, 9)
                dut.sex[i].value = 1 if sex == 'F' else 0
                dut.music[i].value = encode(music, MUSIC_MAP)
                dut.sport[i].value = encode(sport, SPORT_MAP)
            else:
                dut.h[i].value = 0
                dut.sex[i].value = 0
                dut.music[i].value = 0
                dut.sport[i].value = 0
                
        # Trigger
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        result = int(dut.result.value)
        if result != tc['exp']:
            raise TestFailure(f"Case '{tc['desc']}': Expected {tc['exp']}, got {result}")
        passed += 1
        
    if passed != len(TEST_CASES):
        raise TestFailure(f"Only {passed}/{len(TEST_CASES)} passed")