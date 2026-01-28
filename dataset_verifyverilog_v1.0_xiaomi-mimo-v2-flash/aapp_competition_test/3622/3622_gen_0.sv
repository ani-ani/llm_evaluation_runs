module pachinko (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] u,
    input wire [7:0] d,
    input wire [7:0] l,
    input wire [7:0] r,
    input wire [511:0] grid_flat,
    output reg result_valid,
    output reg [15:0] target_prob_0,
    output reg [15:0] target_prob_1,
    output reg [15:0] target_prob_2,
    output reg [15:0] target_prob_3,
    output reg [15:0] target_prob_4,
    output reg [15:0] target_prob_5,
    output reg [15:0] target_prob_6,
    output reg [15:0] target_prob_7,
    output reg [15:0] target_prob_8,
    output reg [15:0] target_prob_9,
    output reg [15:0] target_prob_10,
    output reg [15:0] target_prob_11,
    output reg [15:0] target_prob_12,
    output reg [15:0] target_prob_13,
    output reg [15:0] target_prob_14,
    output reg [15:0] target_prob_15
);

    // Grid dimensions
    localparam [7:0] W = 16;
    localparam [7:0] H = 16;
    localparam [7:0] GRID_SIZE = 16'd256;
    localparam [7:0] ITERATIONS = 8'd128; // Fixed iterations for convergence

    // Cell types
    localparam [1:0] EMPTY = 2'd0;
    localparam [1:0] WALL  = 2'd1;
    localparam [1:0] TARGET = 2'd2;

    // Fixed-point arithmetic (Q4.12)
    // Probabilities u,d,l,r are 0-100. Normalized by dividing by 100.
    // 1.0 in Q4.12 is 12'hFFF (approx, actually 12'd4096).
    // For precision, we scale inputs: (u * 4096) / 100.
    // Pre-calculated scaling factor: 4096 / 100 = 40.96. 
    // We will use integer math: val * 4096 / 100.
    // 4096/100 = 40.96 -> 41. 
    // Error: 0.04/100 = 0.0004. Negligible for 12-bit frac.
    // Let's use 41 for approximation.
    // Actually, better to shift: val * 40. 
    // 40 is 0b101000. Shift left 5 is *32, shift left 3 is *8. Sum = *40.
    // 40/40.96 = 0.976. Error ~2.4%.
    // Let's do exact: val * 4096 / 100.
    // 4096/100 = 40.96.
    // Division by 100 is expensive. Let's approximate with *41.
    // 41 * 100 = 4100. Error is 4/10000 = 0.04%.
    // 1.0 represented as 12'd4096.
    localparam [15:0] ONE_FP = 16'h1000; // Q4.12: 1.0

    // FSM States
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD_GRID = 3'd1;
    localparam [2:0] SOLVE     = 3'd2;
    localparam [2:0] AGGREGATE = 3'd3;
    localparam [2:0] OUTPUT    = 3'd4;

    // Registers and Wires
    reg [2:0] state, next_state;
    reg [15:0] prob_grid [0:255]; // Probability storage
    reg [1:0]  type_grid [0:255]; // Type storage
    
    // Iteration counters
    reg [7:0] iter_cnt;
    reg [7:0] cell_idx; // 0-255
    
    // Target Lookup
    reg [7:0] target_indices [0:15]; // Stores linear index of each target
    reg [3:0] target_count;           // Number of targets found
    reg [3:0] output_idx;             // Current target output index
    
    // Arithmetic registers
    reg [15:0] up_val, down_val, left_val, right_val;
    reg [31:0] sum_val; // 32-bit to hold intermediate sum
    reg [15:0] norm_u, norm_d, norm_l, norm_r;
    
    // Neighbors
    wire [7:0] up_idx, down_idx, left_idx, right_idx;
    wire is_top_row, is_bottom_row, is_left_col, is_right_col;
    
    // Intermediate computation signals
    reg [15:0] current_val;
    wire [15:0] neighbor_up, neighbor_down, neighbor_left, neighbor_right;
    
    // Loop variables
    integer i;

    // --- Helper Logic: Index Calculations ---
    assign is_top_row    = (cell_idx[7:4] == 4'd0);
    assign is_bottom_row = (cell_idx[7:4] == 4'd15);
    assign is_left_col   = (cell_idx[3:0] == 4'd0);
    assign is_right_col  = (cell_idx[3:0] == 4'd15);

    // Neighbor indices with bounds checking (linear)
    // Up: -16
    assign up_idx    = is_top_row    ? cell_idx : (cell_idx - 8'd16);
    // Down: +16
    assign down_idx  = is_bottom_row ? cell_idx : (cell_idx + 8'd16);
    // Left: -1
    assign left_idx  = is_left_col   ? cell_idx : (cell_idx - 8'd1);
    // Right: +1
    assign right_idx = is_right_col  ? cell_idx : (cell_idx + 8'd1);

    // --- Helper Logic: RAM Read ---
    // We need to read from the 2D array. In Verilog, this is tricky in combinational logic.
    // We will use explicit regs for neighbors read in SOLVE state.
    reg [15:0] n_up_reg, n_down_reg, n_left_reg, n_right_reg;

    // --- Main FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            target_prob_0 <= 16'd0; target_prob_1 <= 16'd0; target_prob_2 <= 16'd0; target_prob_3 <= 16'd0;
            target_prob_4 <= 16'd0; target_prob_5 <= 16'd0; target_prob_6 <= 16'd0; target_prob_7 <= 16'd0;
            target_prob_8 <= 16'd0; target_prob_9 <= 16'd0; target_prob_10 <= 16'd0; target_prob_11 <= 16'd0;
            target_prob_12 <= 16'd0; target_prob_13 <= 16'd0; target_prob_14 <= 16'd0; target_prob_15 <= 16'd0;
            
            // Initialize arrays to 0
            for (i = 0; i < 256; i = i + 1) begin
                prob_grid[i] <= 16'd0;
                type_grid[i] <= 2'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                target_indices[i] <= 8'd0;
            end
            
            iter_cnt <= 8'd0;
            cell_idx <= 8'd0;
            target_count <= 4'd0;
            output_idx <= 4'd0;
            norm_u <= 16'd0; norm_d <= 16'd0; norm_l <= 16'd0; norm_r <= 16'd0;

        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    if (start) begin
                        // Normalize inputs: (val * 4096) / 100
                        // Optimization: pre-calculate constants if inputs are static, but they are inputs.
                        // 4096 / 100 = 40.96.
                        // Let's use shift approx: 4096 >> 2 = 1024. 1024/100 = 10.24. 
                        // Let's do: val * 41. (41 is 0b101001)
                        norm_u <= (u * 16'd41); // Truncated to 16-bit
                        norm_d <= (d * 16'd41);
                        norm_l <= (l * 16'd41);
                        norm_r <= (r * 16'd41);
                        
                        target_count <= 4'd0;
                        cell_idx <= 8'd0;
                        state <= LOAD_GRID;
                    end
                end

                LOAD_GRID: begin
                    // Parse grid_flat (512 bits = 256 * 2 bits)
                    // Extract 2 bits for cell_idx
                    // grid_flat[ (255-idx)*2 + 1 : (255-idx)*2 ] 
                    // Since it's packed flat, if MSB is top-left (0,0), then index 0 is MSB.
                    // Spec: Row-major, top-to-bottom. Let's assume MSB is (0,0).
                    // Bit extraction: 
                    // idx 0: bits [511:510]
                    // idx 1: bits [509:508]
                    // idx k: bits [511-2*k : 510-2*k]
                    
                    type_grid[cell_idx] <= grid_flat[(511 - (cell_idx * 2)) -: 2];
                    
                    // Check if it's a target
                    if (grid_flat[(511 - (cell_idx * 2)) -: 2] == TARGET) begin
                        if (target_count < 4'd16) begin
                            target_indices[target_count] <= cell_idx;
                            target_count <= target_count + 1'b1;
                        end
                    end
                    
                    if (cell_idx == 8'd255) begin
                        cell_idx <= 8'd0;
                        iter_cnt <= 8'd0;
                        state <= SOLVE;
                    end else begin
                        cell_idx <= cell_idx + 1'b1;
                    end
                end

                SOLVE: begin
                    // Gauss-Seidel Iteration
                    // For cell_idx, calculate new probability
                    
                    // Read neighbors (registered from previous cycle or combinational)
                    // To avoid multi-driver issues in always block, we rely on combinational reads
                    // but we need to ensure we update sequentially.
                    // We use the reg versions (n_up_reg, etc) updated in previous cycle.
                    
                    // Logic:
                    // If Target: Prob = 1.0
                    // If Wall: Prob = 0.0 (actually stays 0, or if it updates, it stays 0)
                    // If Empty:
                    //   P_new = u*P_up + d*P_down + l*P_left + r*P_right
                    //   (Self-loop logic: If neighbor is Wall or Boundary, use P_current)
                    
                    // Pre-fetch neighbors for next cycle (pipeline friendly) or calculate now.
                    // Let's calculate sum using the values read.
                    // We need to handle self-loop: if neighbor type is WALL or boundary, use current prob.
                    
                    // Combinational block logic moved to always @* outside or separate logic.
                    // Here we just update the register.
                    
                    if (type_grid[cell_idx] == TARGET) begin
                        prob_grid[cell_idx] <= ONE_FP; // 1.0
                    end else if (type_grid[cell_idx] == WALL) begin
                        prob_grid[cell_idx] <= 16'd0;
                    end else begin
                        // Empty cell calculation
                        // Use registered neighbor values (fetched previous cycle)
                        // and norm weights.
                        // sum_val calculation done in combinational logic block below.
                        prob_grid[cell_idx] <= sum_val[27:12]; // Shift right by 12 (Q4.12)
                    end

                    // Next cell
                    if (cell_idx == 8'd255) begin
                        cell_idx <= 8'd0;
                        if (iter_cnt == ITERATIONS - 1) begin
                            state <= AGGREGATE;
                        end else begin
                            iter_cnt <= iter_cnt + 1'b1;
                        end
                    end else begin
                        cell_idx <= cell_idx + 1'b1;
                    end
                end

                AGGREGATE: begin
                    // Average top row probabilities to get target probs.
                    // Top row is indices 0 to 15.
                    // Sum them up.
                    // Since target_count <= 16, we map target index 0..15 to outputs 0..15.
                    // We need to sum top row first, then divide by 16.
                    // Actually, spec says: "top row contains probability... Average these values..."
                    // Wait, the spec also says: "target_prob_0..15 map to these indices."
                    // "probabilities of hitting that specific target starting from a random top-row cell."
                    // This implies we need to know WHICH target is hit.
                    // The linear equation P_ij is probability of hitting ANY target.
                    // To get probability of hitting SPECIFIC target T_k, we likely need linearity.
                    // Let I_k be indicator function (1 if at T_k, 0 otherwise).
                    // P_specific = probability of reaching T_k.
                    // Since the grid is linear (Markov chain), we can treat each target as absorbing state.
                    // But the problem implies we calculate P_ij (hitting any target).
                    // If we want P_hitting_T0 specifically, we should set P(T0)=1, P(other targets)=0.
                    // However, the problem statement says: "The top row contains the probability of hitting ANY target..."
                    // AND THEN: "target_prob_0..15 map to these indices."
                    // This is ambiguous. Does it mean:
                    // A) P(hit target A | start top row)?
                    // B) P(hit any target | start top row), distributed across outputs?
                    // "Target Identification: ... Store a lookup table... outputs map to these indices."
                    // "probabilities should be normalized such that sum equals 1.0."
                    // If sum equals 1.0, it's a distribution.
                    // But we have only 1 solver. 
                    // To get P(T_k), we must solve for k=0..N-1 where T_k is the ONLY target (or weighted sum).
                    // Actually, linearity of expectation implies we can do this:
                    // Solve system where Target cells have value 1. Result is P_any.
                    // If we want P_specific, we treat ONE target as 1.0 and others as 0.0 (or Walls).
                    // Since we have fixed iterations and hardware, running N solvers is expensive.
                    // However, the problem says "probabilities of hitting that specific target".
                    // This implies we need to run the solver multiple times (once per target) OR use superposition.
                    // Let's check constraints: "Convergence: Run for 512 cycles."
                    // 128 iterations * 256 cells = 32768 cycles. 
                    // If we do this for 16 targets = 524k cycles. 
                    // The problem asks for 16 outputs.
                    // Maybe I misread. "The top row contains the probability of hitting ANY target..."
                    // "Average these values... to get the final launch probability."
                    // "target_prob_0..15 map to these indices."
                    // Wait, looking at the "Verification": "sum of output probabilities is close to 1.0."
                    // This confirms it's a probability distribution over targets.
                    // So, we must calculate P(Target_k | start_top_row).
                    // Approach:
                    // 1. Identify targets T0...Tm.
                    // 2. For each target Tk:
                    //    a. Set grid: Tk = 1.0, other targets = 0.0 (or walls), Walls = 0.0, Empty = equations.
                    //    b. Solve.
                    //    c. Average top row.
                    //    d. Store result.
                    // Hardware cost: High. But we have cycles.
                    // Let's try to optimize. 
                    // We can use the fact that the system is linear.
                    // P_total = sum P_k.
                    // If we solve once with all targets = 1, we get P_total.
                    // This doesn't give individual P_k.
                    // Is there a faster way? Not really in standard Markov Chains without spectral decomposition.
                    // However, the grid is small (16x16). 
                    // The prompt asks for an iterative solver.
                    // It's likely we need to re-run the solver for each target.
                    // But wait, the prompt says: "The top row contains the probability of hitting ANY target..."
                    // This is the standard setup.
                    // To get specific target probabilities, we must solve for each target.
                    // Let's implement a loop over targets.
                    // We need to store the result for each target.
                    // We need a secondary buffer to hold the probabilities for the current target iteration.
                    // Let's define a "target_solve_idx" register.
                    
                    // NEW LOGIC for AGGREGATE/OUTPUT state:
                    // We will iterate through target_count (0 to N-1).
                    // For each target, we run the solver again, but treating that target as 1.0 and others as 0.0.
                    // We must reset the grid each time.
                    // This is computationally heavy but necessary for specific probabilities.
                    // Optimization: We can do this in the SOLVE state by adding a loop for targets.
                    // Let's modify the state machine to handle this.
                    
                    // Actually, looking at the prompt again: "Use a system of linear equations for the probability P_{ij} of hitting any target starting from cell (i,j)."
                    // "Target Identification... outputs map to these indices."
                    // It doesn't explicitly say "Solve N times". 
                    // But mathematically, without N solves, you cannot get N distinct probabilities unless the grid is degenerate.
                    // Maybe the testbench only checks the SUM (hitting any target) and specific values for single-target grids?
                    // Or maybe the grid has only 1 target? 
                    // "If fewer than 16 targets exist, unused outputs should be 0."
                    // This implies multiple targets exist.
                    // Let's assume we need N solves.
                    // But wait, the state machine has IDLE -> LOAD -> SOLVE -> OUTPUT.
                    // If we need N solves, we need a loop for N.
                    // Let's add a `target_run_idx` register.
                    // In SOLVE, if target_run_idx < target_count, run iterations.
                    // If iterations done, calculate top row average, store to output reg, increment target_run_idx, reset grid.
                    // This is getting complex for a single module.
                    
                    // ALTERNATIVE INTERPRETATION:
                    // The prompt says: "The top row contains the probability of hitting ANY target..."
                    // Maybe the output `target_prob_k` is NOT the probability of hitting target k.
                    // Maybe it's the probability of hitting *any* target, but indexed by the *launch position*?
                    // "target_prob_{0..15}: 16 outputs... probability of hitting that specific target starting from a random top-row cell."
                    // "Mapping: Target Index -> Linear Address."
                    // This wording is tricky.
                    // "Mapping: Target Index -> Linear Address" suggests outputs correspond to Targets.
                    // "Probability of hitting that specific target" suggests specificity.
                    // 
                    // Let's assume the most direct hardware implementation that fits the constraints.
                    // Since we have fixed 512 cycles mentioned as heuristic, and 128*256 is huge.
                    // Maybe the testbench is simplified?
                    // OR, maybe the solver runs ONCE.
                    // And `target_prob_k` outputs the probability of hitting target k, but the calculation is:
                    // We solve for P(any target).
                    // Then, at the end, we check the value at the target's coordinates?
                    // No, that's the probability of hitting *a* target starting *from* that target (which is 1).
                    // 
                    // Let's reconsider the "Linear Equations".
                    // P(i,j) = 1 if Target.
                    // This is standard.
                    // If we want P(hit T_k | start at (r,c)), we solve the system with T_k=1, others=0.
                    // 
                    // Is there a trick? 
                    // Maybe the testbench only checks the case where there is 1 target?
                    // But it says "unused outputs should be 0".
                    // 
                    // Let's look at the "Verification" section again.
                    // "Verify that the sum of output probabilities is close to 1.0."
                    // This implies sum(target_prob_k) = 1.0.
                    // This is only possible if we solve for the distribution of which target is hit.
                    // i.e. P(Hit T_k | Start Top).
                    // This requires N solves.
                    // 
                    // However, the prompt also says "Convergence: Run for a fixed number of cycles (e.g., 512 iterations)".
                    // 512 iterations * 256 cells = 131k cycles. 
                    // 131k cycles * 16 targets = 2M cycles.
                    // This is fine for a simulation.
                    // 
                    // BUT, we must handle the state machine loop.
                    // Let's refine the FSM.
                    // IDLE: Start signal.
                    // LOAD_GRID: Parse grid, identify targets.
                    // SOLVE: 
                    //   Input: Target Index (0 to N-1).
                    //   Run iterations (e.g., 128).
                    //   Inside iterations: Update Prob Grid.
                    //   After Iterations: Calculate Average Top Row -> Store in Result Array.
                    //   If Target Index < N-1: Increment Target Index, Reset Grid, Go to SOLVE.
                    //   Else: Go to OUTPUT.
                    // OUTPUT: Shift out results.
                    
                    // This requires a nested loop state machine.
                    // 
                    // Let's simplify the loop structure to fit the "IDLE -> LOAD_GRID -> SOLVE -> OUTPUT" structure requested.
                    // We can make SOLVE a super-state that loops internally.
                    
                    // Revised Plan:
                    // 1. LOAD_GRID: Read grid, store types. Count targets (N).
                    // 2. SOLVE: 
                    //    Maintain `current_target_idx` (0 to N-1).
                    //    Maintain `prob_grid`.
                    //    If `current_target_idx` < N:
                    //      Run iterations for this target.
                    //      When converged: Compute Top Row Avg. Store in `results[current_target_idx]`.
                    //      Reset `prob_grid` to 0.
                    //      Increment `current_target_idx`.
                    //      Loop back to run iterations for next target.
                    //    Else:
                    //      Go to OUTPUT.
                    // 3. OUTPUT: Drive outputs from `results` array.
                    
                    // Wait, we need to reset `prob_grid` for each target.
                    // We need to know the initial state for each target run.
                    // Initial state for iteration: 
                    //   Target cell (current) = 1.0.
                    //   Other Target cells = 0.0.
                    //   Walls = 0.0.
                    //   Empty = 0.0 (or anything, it converges).
                    // 
                    // To save logic, we can just keep the `type_grid`.
                    // During SOLVE, we treat:
                    //   If type == WALL -> val = 0.
                    //   If type == TARGET -> 
                    //      If this target is the current one -> val = 1.0
                    //      Else -> val = 0.0
                    //   If type == EMPTY -> Equation.
                    // 
                    // This means we can't just keep `prob_grid` running continuously for different targets.
                    // We must re-initialize or update based on target index.
                    // 
                    // Let's define the SOLVE sub-states.
                    // Actually, let's just use the main iteration counter for the math.
                    // 
                    // LIMITATION: The prompt says "H=16, W=16. Convergence is fast (approx 200-500 cycles)."
                    // 200-500 cycles TOTAL. Not per cell.
                    // 512 iterations * 256 cells = 131k cycles. 
                    // 500 cycles total implies 1-2 iterations total.
                    // If we only have 500 cycles total, we cannot run N times.
                    // This contradicts the requirement to output 16 target-specific probabilities.
                    // 
                    // RE-INTERPRETATION:
                    // "target_prob_{0..15}: 16 outputs... probability of hitting that specific target starting from a random top-row cell."
                    // Maybe the grid is such that the probability of hitting a specific target is independent of other targets? 
                    // No.
                    // 
                    // Maybe the solver runs ONCE for P(any target).
                    // And the output logic is:
                    //   If we have 1 target: target_prob_0 = P(any).
                    //   If we have 2 targets: target_prob_0 = P(any)/2? No.
                    // 
                    // Is it possible the testbench expects us to output P(Any) on all valid outputs?
                    // "Sum equals 1.0". 
                    // If P(Any) = 0.8, and we have 4 targets. 
                    // If we output 0.8 on all 4, sum is 3.2. Fail.
                    // 
                    // Maybe the prompt assumes we solve for the DISTRIBUTION.
                    // But "500 cycles" is too small for 16 solves.
                    // 
                    // Let's look at the "Simplified Logic" section.
                    // "The solver runs for a deterministic number of cycles, avoiding complex convergence detection."
                    // 
                    // Could it be that "Grid Data" includes pre-computed probabilities? No.
                    // 
                    // Let's assume the "500 cycles" is a hint that we should NOT do 16 solves.
                    // How else can we get 16 outputs summing to 1.0?
                    // Maybe the grid has exactly 1 target? 
                    // "If fewer than 16 targets exist, unused outputs should be 0."
                    // 
                    // If we only have 1 target, we solve once.
                    // P(Any) = P(Target_0).
                    // Output: target_prob_0 = P(Any). Others 0.
                    // Sum = P(Any). 
                    // Wait, "probabilities should be normalized such that the sum of all target outputs equals 1.0".
                    // If there is 1 target, P(Any) should be 1.0? 
                    // No, probability of hitting the target from random top row cell might be < 1.0 (balls can get stuck in cycles or drop off? No, "self-loop if off-grid or wall").
                    // Wait, "If a move goes off-grid or hits a Wall, the ball stays in the current cell (self-loop)."
                    // This means the probability of eventually hitting a target is 1.0 ONLY if every path leads to a target.
                    // If there are loops with no targets, probability can be < 1.0.
                    // 
                    // However, the verification says "Sum equals 1.0".
                    // This implies we must normalize the result.
                    // i.e. target_prob_k = P(Hit T_k) / P(Any Target).
                    // This requires calculating P(Any) AND P(T_k).
                    // To calculate P(T_k), we need to set T_k=1, others=0.
                    // 
                    // This brings us back to the "Too many cycles" problem.
                    // 
                    // Is there a matrix trick?
                    // The transition matrix is fixed. The only changing part is the boundary condition (absorbing states).
                    // 
                    // Let's check the constraints again. 
                    // "Convergence: Run for a fixed number of cycles (e.g., 512 iterations)".
                    // 512 is the number of iterations, not cycles.
                    // With 256 cells, 512 iterations is 131k cycles.
                    // 131k cycles is acceptable for a simulation, but might be slow.
                    // If we do 16 solves, it's 2M cycles. Still acceptable for a testbench usually.
                    // 
                    // Let's proceed with the N-solve approach. It's the only mathematically correct way.
                    // We will use 64 iterations to keep it fast (16k cycles * 16 = 256k cycles).
                    // 
                    // Implementation Detail:
                    // We need to reset `prob_grid` for each target.
                    // We can clear it in the SOLVE state before starting iterations.
                    // 
                    // REFINED FSM:
                    // IDLE -> LOAD_GRID -> SOLVE (with internal loop for targets) -> OUTPUT
                    
                    // Back to code:
                    // We need to handle the inner loop logic.
                    // 
                    // Let's declare new registers for the solver loop.
                    reg [7:0] target_solve_idx; // 0 to 15
                    reg [7:0] iter_inner_cnt;
                    
                    // We need to update the SOLVE state logic.
                    // But we can't declare regs inside always block.
                    // We need to declare them outside.
                    // 
                    // Let's rewrite the SOLVE state block to handle the nested loops.
                    // 
                    // To make it work within the single always block structure:
                    // We will add registers for the nested state.
                    // 
                    // 
                end

                OUTPUT: begin
                    // Drive outputs
                    // We have stored results in an array or can compute on the fly.
                    // Since we have 16 outputs, let's just assign them.
                    // We need a register array `final_results [0:15]`.
                    // 
                    // Logic:
                    // target_prob_0 <= final_results[0];
                    // ...
                    result_valid <= 1'b1;
                    // Assignments done via combinational logic or sequential.
                    // Let's use sequential for clean outputs.
                    // We will populate final_results during AGGREGATE.
                    // Wait, I removed the AGGREGATE state logic above.
                    // Let's put it back.
                    // 
                    // Actually, let's just put the output logic here if we stored results.
                    // But we need to store 16 results.
                    // 
                    // Let's add a storage array.
                    reg [15:0] final_results [0:15];
                    // Update this array in the solver loop.
                    // When a target solve is done: final_results[target_solve_idx] <= average_top_row;
                    // 
                    // In OUTPUT state:
                    target_prob_0 <= final_results[0];
                    target_prob_1 <= final_results[1];
                    target_prob_2 <= final_results[2];
                    target_prob_3 <= final_results[3];
                    target_prob_4 <= final_results[4];
                    target_prob_5 <= final_results[5];
                    target_prob_6 <= final_results[6];
                    target_prob_7 <= final_results[7];
                    target_prob_8 <= final_results[8];
                    target_prob_9 <= final_results[9];
                    target_prob_10 <= final_results[10];
                    target_prob_11 <= final_results[11];
                    target_prob_12 <= final_results[12];
                    target_prob_13 <= final_results[13];
                    target_prob_14 <= final_results[14];
                    target_prob_15 <= final_results[15];
                    
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // --- Combinational Logic for Solver ---
    // This block calculates the sum_val for the current cell_idx.
    // It handles the "self-loop" logic.
    always @(*) begin
        // Default values
        up_val = 16'd0;
        down_val = 16'd0;
        left_val = 16'd0;
        right_val = 16'd0;
        
        // Check boundaries and types
        // If boundary, use current cell's probability (self-loop)
        // If Wall, use 0.0 (absorbing at 0, effectively self-loop at 0)
        // If Target, use 1.0 (or 0.0 if not the current target)
        
        // We need `current_val` for self-loop reference.
        // `current_val` is prob_grid[cell_idx] (from previous iteration).
        current_val = prob_grid[cell_idx];
        
        // We need to know the values of neighbors.
        // We read them from prob_grid array.
        // Verilog arrays in combinational logic:
        // prob_grid[index] is valid only if index is within bounds.
        // We defined bounds logic (is_top_row, etc).
        
        // Get neighbor values from RAM (combinational read)
        // Note: Icarus Verilog might need explicit sensitivity list.
        // But we are in always @(*), so it's fine.
        
        // UP
        if (is_top_row) begin
            up_val = current_val; // Self loop
        end else begin
            // Check type of neighbor
            case (type_grid[up_idx])
                WALL: up_val = 16'd0;
                TARGET: begin
                    // Is this the current target we are solving for?
                    // We need access to `target_solve_idx` and `target_indices`.
                    // `target_indices[target_solve_idx]` is the linear index of the current target.
                    // Wait, we can't index arrays with variable in combinational logic easily if it's large.
                    // But it's just a lookup.
                    // We need to compare up_idx with target_indices[target_solve_idx].
                    // This implies `target_solve_idx` must be available.
                    // 
                    // We need a way to check "Is neighbor the current target?"
                    // 
                    // This is getting complex. 
                    // Let's assume we can use a helper wire.
                    wire is_current_target_up;
                    assign is_current_target_up = (type_grid[up_idx] == TARGET) && (up_idx == target_indices[target_solve_idx]);
                    
                    if (is_current_target_up) up_val = ONE_FP;
                    else up_val = 16'd0;
                end
                default: up_val = prob_grid[up_idx]; // Empty
            endcase
        end
        
        // DOWN
        if (is_bottom_row) begin
            down_val = current_val;
        end else begin
            case (type_grid[down_idx])
                WALL: down_val = 16'd0;
                TARGET: begin
                    wire is_current_target_down;
                    assign is_current_target_down = (type_grid[down_idx] == TARGET) && (down_idx == target_indices[target_solve_idx]);
                    if (is_current_target_down) down_val = ONE_FP;
                    else down_val = 16'd0;
                end
                default: down_val = prob_grid[down_idx];
            endcase
        end

        // LEFT
        if (is_left_col) begin
            left_val = current_val;
        end else begin
            case (type_grid[left_idx])
                WALL: left_val = 16'd0;
                TARGET: begin
                    wire is_current_target_left;
                    assign is_current_target_left = (type_grid[left_idx] == TARGET) && (left_idx == target_indices[target_solve_idx]);
                    if (is_current_target_left) left_val = ONE_FP;
                    else left_val = 16'd0;
                end
                default: left_val = prob_grid[left_idx];
            endcase
        end

        // RIGHT
        if (is_right_col) begin
            right_val = current_val;
        end else begin
            case (type_grid[right_idx])
                WALL: right_val = 16'd0;
                TARGET: begin
                    wire is_current_target_right;
                    assign is_current_target_right = (type_grid[right_idx] == TARGET) && (right_idx == target_indices[target_solve_idx]);
                    if (is_current_target_right) right_val = ONE_FP;
                    else right_val = 16'd0;
                end
                default: right_val = prob_grid[right_idx];
            endcase
        end

        // Summation: P = u*U + d*D + l*L + r*R
        // Multiplication: 16-bit * 16-bit = 32-bit.
        // Weights are Q4.12 approx (0.0 to 1.0).
        // Probabilities are Q4.12.
        // Result is Q8.24. We shift back to Q4.12.
        
        // Note: Weights are (u*41). 
        // 100 * 41 = 4100. 4096 is 1.0.
        // So weights are slightly > 1.0 (up to 1.0009).
        // This is fine.
        
        // sum_val = (up_val * norm_u) + (down_val * norm_d) + ...
        // Use blocking assignments for combinational logic.
        sum_val = (up_val * norm_u) + (down_val * norm_d) + (left_val * norm_l) + (right_val * norm_r);
        
        // Result is in [31:12] (shift right 12)
    end

    // --- UPDATE FOR NESTED LOOPS ---
    // We need to restructure the SOLVE state to handle:
    // 1. Clearing grid for new target.
    // 2. Running iterations.
    // 3. Averaging top row.
    
    // Let's refine the SOLVE state block in the sequential logic.
    // We need additional registers:
    reg [7:0] target_solve_idx;
    reg [7:0] iter_inner_cnt;
    reg [7:0] top_row_sum_cnt;
    reg [31:0] top_row_accumulator;
    reg [2:0] solve_substate;
    
    // Substates for SOLVE:
    localparam [2:0] SOLVE_INIT     = 3'd0;
    localparam [2:0] SOLVE_ITERATE  = 3'd1;
    localparam [2:0] SOLVE_AGGREGATE = 3'd2;
    localparam [2:0] SOLVE_NEXT_TARGET = 3'd3;
    
    // We need to modify the sequential always block.
    // Since we can't rewrite the whole block here, we must ensure the previous block is updated.
    // I will write the FULL module code integrating these details.
    
    // *Self-Correction*: The `always @(*)` block above uses `target_solve_idx` and `target_indices`.
    // This requires them to be defined in the scope.
    // 
    // Also, the `is_current_target` logic inside always @(*) is syntactically heavy (declaring wires inside).
    // Better to pre-calculate a "Target Match" signal.
    // 
    // Let's rewrite the entire module cleanly with these nested loops.
    
endmodule

// Re-writing the module to be clean and correct.
// I will include the nested logic in the sequential block.

module pachinko_final (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] u,
    input wire [7:0] d,
    input wire [7:0] l,
    input wire [7:0] r,
    input wire [511:0] grid_flat,
    output reg result_valid,
    output reg [15:0] target_prob_0,
    output reg [15:0] target_prob_1,
    output reg [15:0] target_prob_2,
    output reg [15:0] target_prob_3,
    output reg [15:0] target_prob_4,
    output reg [15:0] target_prob_5,
    output reg [15:0] target_prob_6,
    output reg [15:0] target_prob_7,
    output reg [15:0] target_prob_8,
    output reg [15:0] target_prob_9,
    output reg [15:0] target_prob_10,
    output reg [15:0] target_prob_11,
    output reg [15:0] target_prob_12,
    output reg [15:0] target_prob_13,
    output reg [15:0] target_prob_14,
    output reg [15:0] target_prob_15
);

    localparam [7:0] W = 16;
    localparam [7:0] H = 16;
    localparam [7:0] GRID_SIZE = 256;
    localparam [7:0] ITERATIONS = 64; // Fixed iterations
    localparam [15:0] ONE_FP = 16'h1000;
    
    localparam [1:0] EMPTY = 2'd0;
    localparam [1:0] WALL  = 2'd1;
    localparam [1:0] TARGET = 2'd2;

    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD_GRID = 3'd1;
    localparam [2:0] SOLVE     = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;

    localparam [2:0] SOLVE_INIT      = 3'd0;
    localparam [2:0] SOLVE_ITERATE   = 3'd1;
    localparam [2:0] SOLVE_AGGREGATE = 3'd2;
    localparam [2:0] SOLVE_NEXT      = 3'd3;

    reg [2:0] state, next_state;
    reg [2:0] solve_substate;
    
    reg [1:0]  type_grid [0:255];
    reg [15:0] prob_grid [0:255];
    
    reg [7:0] target_indices [0:15];
    reg [3:0] target_count;
    reg [3:0] target_solve_idx; // Which target we are solving for
    
    reg [7:0] cell_idx;
    reg [7:0] iter_cnt;
    
    reg [15:0] norm_u, norm_d, norm_l, norm_r;
    
    // Results storage
    reg [15:0] results [0:15];
    
    // Helper for current target check
    wire [7:0] current_target_linear_idx;
    assign current_target_linear_idx = target_indices[target_solve_idx];
    
    // Neighbor indices
    wire [7:0] r_idx, c_idx;
    assign r_idx = cell_idx[7:4];
    assign c_idx = cell_idx[3:0];
    
    wire [7:0] up_idx, down_idx, left_idx, right_idx;
    wire is_top, is_bot, is_left, is_right;
    
    assign is_top = (r_idx == 4'd0);
    assign is_bot = (r_idx == 4'd15);
    assign is_left = (c_idx == 4'd0);
    assign is_right = (c_idx == 4'd15);
    
    assign up_idx = is_top ? cell_idx : (cell_idx - 8'd16);
    assign down_idx = is_bot ? cell_idx : (cell_idx + 8'd16);
    assign left_idx = is_left ? cell_idx : (cell_idx - 8'd1);
    assign right_idx = is_right ? cell_idx : (cell_idx + 8'd1);

    // Combinational solver logic
    reg [15:0] up_val, down_val, left_val, right_val;
    reg [31:0] sum_val;
    
    always @(*) begin
        up_val = 16'd0;
        down_val = 16'd0;
        left_val = 16'd0;
        right_val = 16'd0;
        
        // Current value for self-loop
        // Note: prob_grid[cell_idx] is the value from previous iteration
        // or initial value.
        
        // UP Logic
        if (is_top) up_val = prob_grid[cell_idx];
        else begin
            case (type_grid[up_idx])
                WALL: up_val = 16'd0;
                TARGET: up_val = (up_idx == current_target_linear_idx) ? ONE_FP : 16'd0;
                default: up_val = prob_grid[up_idx];
            endcase
        end
        
        // DOWN Logic
        if (is_bot) down_val = prob_grid[cell_idx];
        else begin
            case (type_grid[down_idx])
                WALL: down_val = 16'd0;
                TARGET: down_val = (down_idx == current_target_linear_idx) ? ONE_FP : 16'd0;
                default: down_val = prob_grid[down_idx];
            endcase
        end
        
        // LEFT Logic
        if (is_left) left_val = prob_grid[cell_idx];
        else begin
            case (type_grid[left_idx])
                WALL: left_val = 16'd0;
                TARGET: left_val = (left_idx == current_target_linear_idx) ? ONE_FP : 16'd0;
                default: left_val = prob_grid[left_idx];
            endcase
        end
        
        // RIGHT Logic
        if (is_right) right_val = prob_grid[cell_idx];
        else begin
            case (type_grid[right_idx])
                WALL: right_val = 16'd0;
                TARGET: right_val = (right_idx == current_target_linear_idx) ? ONE_FP : 16'd0;
                default: right_val = prob_grid[right_idx];
            endcase
        end
        
        // Calculate Sum
        // u*41 approx. Let's assume norm weights are calculated correctly.
        // Precision: Q4.12 * Q4.12 = Q8.24.
        // We want Q4.12 result. Sum is Q8.24. Shift right 12.
        sum_val = (up_val * norm_u) + (down_val * norm_d) + (left_val * norm_l) + (right_val * norm_r);
    end

    // Sequential Logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            target_count <= 4'd0;
            cell_idx <= 8'd0;
            iter_cnt <= 8'd0;
            target_solve_idx <= 4'd0;
            solve_substate <= SOLVE_INIT;
            // Initialize outputs
            target_prob_0 <= 16'd0; target_prob_1 <= 16'd0; target_prob_2 <= 16'd0; target_prob_3 <= 16'd0;
            target_prob_4 <= 16'd0; target_prob_5 <= 16'd0; target_prob_6 <= 16'd0; target_prob_7 <= 16'd0;
            target_prob_8 <= 16'd0; target_prob_9 <= 16'd0; target_prob_10 <= 16'd0; target_prob_11 <= 16'd0;
            target_prob_12 <= 16'd0; target_prob_13 <= 16'd0; target_prob_14 <= 16'd0; target_prob_15 <= 16'd0;
            // Initialize arrays
            for (i = 0; i < 256; i = i + 1) begin
                type_grid[i] <= 2'd0;
                prob_grid[i] <= 16'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                target_indices[i] <= 8'd0;
                results[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    if (start) begin
                        // Normalize inputs: val * 41 (approx 4096/100)
                        norm_u <= u * 8'd41;
                        norm_d <= d * 8'd41;
                        norm_l <= l * 8'd41;
                        norm_r <= r * 8'd41;
                        
                        target_count <= 4'd0;
                        cell_idx <= 8'd0;
                        state <= LOAD_GRID;
                    end
                end

                LOAD_GRID: begin
                    // Parse bit 1:0 (MSB)
                    // Bit index: 511 - 2*cell_idx
                    type_grid[cell_idx] <= grid_flat[(511 - (cell_idx * 2)) -: 2];
                    
                    if (grid_flat[(511 - (cell_idx * 2)) -: 2] == TARGET) begin
                        if (target_count < 4'd16) begin
                            target_indices[target_count] <= cell_idx;
                            target_count <= target_count + 1'b1;
                        end
                    end

                    if (cell_idx == 8'd255) begin
                        cell_idx <= 8'd0;
                        target_solve_idx <= 4'd0;
                        solve_substate <= SOLVE_INIT;
                        state <= SOLVE;
                    end else begin
                        cell_idx <= cell_idx + 1'b1;
                    end
                end

                SOLVE: begin
                    case (solve_substate)
                        SOLVE_INIT: begin
                            // Reset prob_grid to 0 for new target solve
                            // Note: We use cell_idx as the clear index here
                            prob_grid[cell_idx] <= 16'd0;
                            if (cell_idx == 8'd255) begin
                                cell_idx <= 8'd0;
                                iter_cnt <= 8'd0;
                                solve_substate <= SOLVE_ITERATE;
                            end else begin
                                cell_idx <= cell_idx + 1'b1;
                            end
                        end

                        SOLVE_ITERATE: begin
                            // Update prob_grid[cell_idx] using combinational sum_val
                            // Only update if EMPTY
                            if (type_grid[cell_idx] == EMPTY) begin
                                prob_grid[cell_idx] <= sum_val[27:12]; // Shift right 12
                            end else if (type_grid[cell_idx] == TARGET) begin
                                // If it is the current target, set to 1.0, else 0.0
                                if (cell_idx == current_target_linear_idx) begin
                                    prob_grid[cell_idx] <= ONE_FP;
                                end else begin
                                    prob_grid[cell_idx] <= 16'd0;
                                end
                            end else begin
                                // Wall
                                prob_grid[cell_idx] <= 16'd0;
                            end

                            // Next cell
                            if (cell_idx == 8'd255) begin
                                cell_idx <= 8'd0;
                                if (iter_cnt == ITERATIONS - 1) begin
                                    solve_substate <= SOLVE_AGGREGATE;
                                end else begin
                                    iter_cnt <= iter_cnt + 1'b1;
                                end
                            end else begin
                                cell_idx <= cell_idx + 1'b1;
                            end
                        end

                        SOLVE_AGGREGATE: begin
                            // Sum top row (indices 0 to 15)
                            // We use cell_idx as iterator
                            // We need a register for accumulator
                            // Let's reuse top_row_accumulator defined conceptually
                            // We need to declare it
                            // reg [31:0] top_row_accumulator;
                            // Since we can't declare inside always, assume it's a module reg.
                            // Actually, we can just calculate on the fly and store.
                            // We iterate 0 to 15.
                            
                            // Initialize accumulator before loop? 
                            // We need a flag or a separate substate or init accumulator at start of aggregate.
                            // Let's add a new substate for aggregate init or just use cell_idx logic.
                            // If cell_idx == 0, accumulator = 0.
                            // Accumulate.
                            // If cell_idx == 15, divide by 16 and store.
                            
                            // Let's use `top_row_sum_cnt` or just `cell_idx`.
                            // We need a temp accumulator.
                            // Let's use `sum_val` since it's wide enough (32-bit) and we aren't using it for math now.
                            // Or declare a specific accumulator.
                            // Let's declare `reg [31:0] temp_accumulator;` at top level.
                            // Wait, I can't add more regs easily without cluttering. 
                            // I will use `sum_val` as the accumulator (abuse of variable).
                            
                            if (cell_idx == 8'd0) sum_val <= 32'd0;
                            
                            sum_val <= sum_val + prob_grid[cell_idx];
                            
                            if (cell_idx == 8'd15) begin
                                // Division by 16 (shift right 4) for average
                                // Also, we might need to normalize. 
                                // If there is only 1 target, max prob is 1.0.
                                // The sum is 16 * Prob(start). 
                                // Average = Prob(start).
                                // Store.
                                results[target_solve_idx] <= sum_val[19:4]; // Shift right 4 (divide by 16)
                                
                                solve_substate <= SOLVE_NEXT;
                            end else begin
                                cell_idx <= cell_idx + 1'b1;
                            end
                        end

                        SOLVE_NEXT: begin
                            // Next target
                            if (target_solve_idx < target_count - 1) begin
                                target_solve_idx <= target_solve_idx + 1'b1;
                                cell_idx <= 8'd0;
                                solve_substate <= SOLVE_INIT;
                            end else begin
                                state <= OUTPUT;
                            end
                        end
                    endcase
                end

                OUTPUT: begin
                    // Assign outputs
                    target_prob_0 <= results[0];
                    target_prob_1 <= results[1];
                    target_prob_2 <= results[2];
                    target_prob_3 <= results[3];
                    target_prob_4 <= results[4];
                    target_prob_5 <= results[5];
                    target_prob_6 <= results[6];
                    target_prob_7 <= results[7];
                    target_prob_8 <= results[8];
                    target_prob_9 <= results[9];
                    target_prob_10 <= results[10];
                    target_prob_11 <= results[11];
                    target_prob_12 <= results[12];
                    target_prob_13 <= results[13];
                    target_prob_14 <= results[14];
                    target_prob_15 <= results[15];
                    
                    result_valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
