import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPERS
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Constants
CLK_NS = 10
MAX_CYCLES = 100000

# Instruction Encoding
OP_COMPUTE = 0
OP_LOCK = 1
OP_UNLOCK = 2

def parse_input(input_str):
    lines = input_str.strip().split('\n')
    first = lines[0].split()
    t, r = int(first[0]), int(first[1])
    tasks = []
    for i in range(t):
        parts = lines[i+1].split()
        start = int(parts[0])
        base_prio = int(parts[1])
        inst_strs = parts[3:] # Skip count a if present in split, usually parts[3] is count
        if len(parts) - 3 != int(parts[2]):
             # Handle case where strings might be merged or split differently
             # Reconstruct: from index 3 to end
             inst_strs = parts[3:]
        
        insts = []
        for s in inst_strs:
            op_char = s[0]
            val = int(s[1:])
            if op_char == 'C':
                # Decompress Cn into n compute instructions
                for _ in range(val):
                    insts.append((OP_COMPUTE, 1)) # Each compute takes 1 unit in this model
            elif op_char == 'L':
                insts.append((OP_LOCK, val - 1)) # 0-indexed resource
            elif op_char == 'U':
                insts.append((OP_UNLOCK, val - 1))
        tasks.append({'start': start, 'base_prio': base_prio, 'insts': insts})
    return t, r, tasks

def calculate_expected_outputs(t, tasks):
    # Python reference implementation of Priority Ceiling Protocol
    # Returns list of (task_id, time)
    
    # Setup
    n = t
    num_tasks = n
    num_resources = 20
    
    # 1. Calculate Resource Ceilings
    ceilings = [0] * num_resources
    for task in tasks:
        for op, operand in task['insts']:
            if op == OP_LOCK:
                ceilings[operand] = max(ceilings[operand], task['base_prio'])
    
    # State
    current_time = 0
    done_tasks = []
    
    # Task State
    task_state = []
    for i in range(n):
        task_state.append({
            'base_prio': tasks[i]['base_prio'],
            'start_time': tasks[i]['start'],
            'pc': 0,
            'completed': False,
            'stack': [], # for nested locks
            'waiting': False, # if blocked
            'blocked_by': -1
        })
    
    owner = [-1] * num_resources
    
    MAX_STEPS = 500000
    step = 0
    
    while len(done_tasks) < n and step < MAX_STEPS:
        step += 1
        
        # Step 1: Identify running tasks
        running = []
        for i in range(n):
            if not task_state[i]['completed'] and current_time >= tasks[i]['start']:
                running.append(i)
        
        if not running:
            # Advance time to next start time
            next_start = 10000000
            for i in range(n):
                if not task_state[i]['completed']:
                    next_start = min(next_start, tasks[i]['start'])
            if next_start == 10000000:
                break
            current_time = next_start
            continue
            
        # Step 2: Determine Priorities and Blocking
        # Reset transient state
        for i in range(n):
            task_state[i]['waiting'] = False
            task_state[i]['blocked_by'] = -1
            
        # Calculate Current Priorities (Fixed point iteration)
        priorities = [0] * n
        for i in range(n):
            priorities[i] = task_state[i]['base_prio']
            
        for _ in range(10): # Max iterations
            changed = False
            # Update priorities based on blocking
            for i in running:
                if task_state[i]['waiting']:
                    blocker = task_state[i]['blocked_by']
                    if blocker != -1:
                        if priorities[i] > priorities[blocker]:
                            priorities[blocker] = priorities[i]
                            changed = True
            if not changed:
                break
                
        # Determine who is actually blocked (needs lock, but cannot acquire)
        # Note: In the simulation, we calculate blocking status based on current locks.
        # If a task is blocked, it stays blocked until the owner releases or ceiling drops.
        # However, the prompt says "Determine... which... are blocked" every cycle.
        
        # Check for new blocking events
        for i in running:
            if task_state[i]['completed']:
                continue
            
            # If already blocked, check if unblocked
            if task_state[i]['waiting']:
                # Is the resource it wants free AND no higher ceiling conflict?
                # Actually, if it was blocked, it means it couldn't lock.
                # It unblocks only when the specific condition passes.
                
                next_inst = tasks[i]['insts'][task_state[i]['pc']]
                if next_inst[0] == OP_LOCK:
                    res = next_inst[1]
                    blocked = False
                    blocker = -1
                    
                    # Condition 1: Resource owned
                    if owner[res] != -1:
                        blocked = True
                        blocker = owner[res]
                    
                    # Condition 2: Ceiling conflict
                    if not blocked:
                        for r_idx in range(num_resources):
                            if owner[r_idx] != -1 and ceilings[r_idx] >= priorities[i]:
                                blocked = True
                                blocker = owner[r_idx]
                                break
                    
                    if not blocked:
                        task_state[i]['waiting'] = False
                        task_state[i]['blocked_by'] = -1
                    else:
                        task_state[i]['blocked_by'] = blocker
                        priorities[blocker] = max(priorities[blocker], priorities[i])
                        
                else:
                    # Should not be waiting if not locking
                    task_state[i]['waiting'] = False
                    
            else:
                # Check if needs to block on next instruction
                next_inst = tasks[i]['insts'][task_state[i]['pc']]
                if next_inst[0] == OP_LOCK:
                    res = next_inst[1]
                    blocked = False
                    blocker = -1
                    
                    # Condition 1: Resource owned
                    if owner[res] != -1:
                        blocked = True
                        blocker = owner[res]
                    
                    # Condition 2: Ceiling conflict
                    if not blocked:
                        for r_idx in range(num_resources):
                            if owner[r_idx] != -1 and ceilings[r_idx] >= priorities[i]:
                                blocked = True
                                blocker = owner[r_idx]
                                break
                    
                    if blocked:
                        task_state[i]['waiting'] = True
                        task_state[i]['blocked_by'] = blocker
                        # Propagate priority
                        priorities[blocker] = max(priorities[blocker], priorities[i])
        
        # Re-evaluate priorities with blocking info
        for _ in range(10):
            changed = False
            for i in running:
                if task_state[i]['waiting']:
                    blocker = task_state[i]['blocked_by']
                    if blocker != -1:
                        if priorities[i] > priorities[blocker]:
                            priorities[blocker] = priorities[i]
                            changed = True
            if not changed:
                break
                
        # Step 3: Execute Instruction
        # Find highest priority non-blocked task
        candidates = []
        for i in running:
            if not task_state[i]['waiting']:
                candidates.append((priorities[i], i))
        
        if not candidates:
            # Deadlock or waiting? Should not happen per problem statement
            # But time might pass if all are waiting? 
            # According to protocol, if all running are blocked, clock doesn't increment on lock? 
            # Actually, if no non-blocked task, we might be stuck. 
            # But problem says "All tasks will eventually complete."
            # If all running are blocked, we must wait for someone to unblock.
            # However, time only increments on Compute.
            # If everyone is waiting on a lock, and no one is computing, time is frozen?
            # In real hardware, this is a deadlock. But the problem guarantees completion.
            # Usually, this implies we should pick nothing and maybe spin?
            # But the prompt says: "Execute... highest... If none... increment clock by one?"
            # Wait, step 3 says: "Execute... If there was no such task... increment clock by one."
            # So if all running are blocked, we do nothing (no execution) and increment clock.
            current_time += 1
            continue
            
        candidates.sort()
        winner = candidates[-1][1]
        
        # Execute
        inst = tasks[winner]['insts'][task_state[winner]['pc']]
        op, operand = inst
        
        if op == OP_COMPUTE:
            current_time += 1
            task_state[winner]['pc'] += 1
            
        elif op == OP_LOCK:
            # Not blocked, so must be able to lock
            owner[operand] = winner
            task_state[winner]['stack'].append(operand)
            task_state[winner]['pc'] += 1
            
        elif op == OP_UNLOCK:
            # Find most recently locked
            res = task_state[winner]['stack'].pop()
            owner[res] = -1
            task_state[winner]['pc'] += 1
            
        # Check completion
        if task_state[winner]['pc'] >= len(tasks[winner]['insts']):
            task_state[winner]['completed'] = True
            done_tasks.append((winner, current_time))
            
    return done_tasks

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_priority_ceiling(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        if has_signal(dut, 'cfg_en'): dut.cfg_en.value = 0
        for _ in range(2):
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_NS, units='ns')
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    
    # Test Cases
    inputs = [
        "3 1\n50 2 5 C1 L1 C1 U1 C1\n1 1 5 C1 L1 C100 U1 C1\n70 3 1 C1",
        "3 3\n5 3 5 C1 L1 C1 U1 C1\n3 2 9 C1 L2 C1 L3 C1 U3 C1 U2 C1\n1 1 9 C1 L3 C3 L2 C1 U2 C1 U3 C1"
    ]
    
    for idx, inp in enumerate(inputs):
        cocotb.log.info(f"Running Test Case {idx+1}")
        
        t, r, tasks = parse_input(inp)
        expected = calculate_expected_outputs(t, tasks)
        
        # Configuration Phase
        if has_signal(dut, 'cfg_en'):
            dut.cfg_en.value = 1
            
            # 1. Load Resources (Address 0-31)
            ceilings = [0] * 32
            for task in tasks:
                for op, operand in task['insts']:
                    if op == OP_LOCK:
                        ceilings[operand] = max(ceilings[operand], task['base_prio'])
            
            for i in range(r):
                dut.cfg_addr.value = i
                dut.cfg_data.value = ceilings[i]
                await RisingEdge(dut.clk)
                
            # 2. Load Tasks (Address 32-63)
            for i in range(t):
                dut.cfg_addr.value = 32 + i
                # Data: Start[15:8] BasePrio[7:0]
                data = (tasks[i]['start'] << 8) | tasks[i]['base_prio']
                dut.cfg_data.value = data
                await RisingEdge(dut.clk)
                
            # 3. Load Instructions (Address 64+)
            base_addr = 64
            for i in range(t):
                for j, (op, operand) in enumerate(tasks[i]['insts']):
                    dut.cfg_addr.value = base_addr + i*128 + j
                    enc = (op << 6) | operand
                    dut.cfg_data.value = enc
                    await RisingEdge(dut.clk)
            
            dut.cfg_en.value = 0
            await RisingEdge(dut.clk)
        
        # Start Simulation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Collect Results
        results = []
        timeout = 0
        while len(results) < t and timeout < 10000:
            if has_signal(dut, 'result_valid') and int(dut.result_valid) == 1:
                tid = int(dut.task_done_id)
                ttime = int(dut.task_done_time)
                results.append((tid, ttime))
                cocotb.log.info(f"Task {tid} finished at {ttime}")
            
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_NS, units='ns')
            timeout += 1
        
        # Verify
        if len(results) != t:
            raise TestFailure(f"Expected {t} tasks, got {len(results)}")
            
        # Sort results by task ID to match expected order
        results.sort(key=lambda x: x[0])
        
        for i in range(t):
            exp_time = expected[i][1]
            got_time = results[i][1]
            if got_time != exp_time:
                raise TestFailure(f"TC{idx+1} Task {i}: Expected {exp_time}, Got {got_time}")
                
        cocotb.log.info(f"Test Case {idx+1} Passed")
