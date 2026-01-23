module airplane_construction (
    input clk,
    input rst_n,
    input start,
    input [2:0] step_count,
    input [7:0] step_times [0:7],
    input [7:0] dependencies [0:7],
    output reg [15:0] min_time,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam BUILD_GRAPH = 3'b001;
    localparam COMPUTE_ORIGINAL = 3'b010;
    localparam TRY_ELIMINATE = 3'b011;
    localparam COMPUTE_ELIMINATED = 3'b100;
    localparam UPDATE_MIN = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Iteration counters
    reg [2:0] elim_idx; // Index of step to eliminate (0 to N-1)
    reg [2:0] node_idx; // Index for topological processing
    
    // Storage for effective times and distances
    reg [7:0] eff_times [0:7];  // Times used for current computation
    reg [15:0] dist [0:7];      // DP distances
    
    // Temporary variable for comparison
    reg [15:0] current_crit;
    
    // Combinational logic to extract original dependencies and times
    wire [7:0] orig_times [0:7];
    wire [7:0] deps [0:7];
    assign orig_times = step_times;
    assign deps = dependencies;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = BUILD_GRAPH;
                else next_state = IDLE;
            end
            BUILD_GRAPH: next_state = COMPUTE_ORIGINAL;
            COMPUTE_ORIGINAL: begin
                if (node_idx > step_count) next_state = TRY_ELIMINATE;
                else next_state = COMPUTE_ORIGINAL;
            end
            TRY_ELIMINATE: next_state = COMPUTE_ELIMINATED;
            COMPUTE_ELIMINATED: begin
                if (node_idx > step_count) next_state = UPDATE_MIN;
                else next_state = COMPUTE_ELIMINATED;
            end
            UPDATE_MIN: begin
                if (elim_idx == step_count - 1) next_state = DONE;
                else next_state = TRY_ELIMINATE;
            end
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Output and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_time <= 16'hFFFF;
            done <= 1'b0;
            elim_idx <= 3'b0;
            node_idx <= 3'b0;
            current_crit <= 16'b0;
            // Initialize eff_times and dist to avoid latches
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                eff_times[i] <= 8'b0;
                dist[i] <= 16'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        min_time <= 16'hFFFF; // Initialize max
                        elim_idx <= 3'b0;
                    end
                end

                BUILD_GRAPH: begin
                    // Initialize for Original Computation
                    // Copy original times
                    eff_times[0] <= orig_times[0];
                    eff_times[1] <= orig_times[1];
                    eff_times[2] <= orig_times[2];
                    eff_times[3] <= orig_times[3];
                    eff_times[4] <= orig_times[4];
                    eff_times[5] <= orig_times[5];
                    eff_times[6] <= orig_times[6];
                    eff_times[7] <= orig_times[7];
                    // Reset node index for DP
                    node_idx <= 3'b0;
                end

                COMPUTE_ORIGINAL: begin
                    if (node_idx == 0) begin
                        // Init distance for node 0
                        dist[0] <= {8'b0, eff_times[0]};
                        node_idx <= 3'd1;
                    end else if (node_idx <= step_count) begin
                        // DP Step
                        if (node_idx < step_count) begin
                            // dist[node_idx] = eff_times[node_idx] + max(dist of predecessors)
                            // We need to check dependencies. Dependencies are stored in 'deps' array.
                            // 'deps[i]' is a mask of steps i depends on.
                            // If deps[node_idx] has bit 'j' set, then j -> node_idx.
                            // We need max(dist[j]) for all j where deps[node_idx][j] == 1.
                            
                            // Since it's combinational logic inside an always block for synthesis, 
                            // we calculate the max predecessor logic here.
                            // However, since we are in a sequential block, we calculate the result based on previous cycle's dist values.
                            // But wait, DP in topological order implies we process node i after all its predecessors are done.
                            // Since we iterate i=0..N-1, and dependencies only depend on lower indices (implied by problem statement typically, or valid topo sort), this works.
                            
                            dist[node_idx] <= {8'b0, eff_times[node_idx]} + get_max_pred_dist(node_idx, deps[node_idx], dist[0], dist[1], dist[2], dist[3], dist[4], dist[5], dist[6], dist[7]);
                        end else begin
                            // Finished: store result in current_crit
                            current_crit <= dist[step_count - 1];
                        end
                        node_idx <= node_idx + 1;
                    end
                end

                TRY_ELIMINATE: begin
                    // Set up for eliminated run
                    // Copy original times but set eff_times[elim_idx] to 0
                    eff_times[0] <= (elim_idx == 0) ? 8'b0 : orig_times[0];
                    eff_times[1] <= (elim_idx == 1) ? 8'b0 : orig_times[1];
                    eff_times[2] <= (elim_idx == 2) ? 8'b0 : orig_times[2];
                    eff_times[3] <= (elim_idx == 3) ? 8'b0 : orig_times[3];
                    eff_times[4] <= (elim_idx == 4) ? 8'b0 : orig_times[4];
                    eff_times[5] <= (elim_idx == 5) ? 8'b0 : orig_times[5];
                    eff_times[6] <= (elim_idx == 6) ? 8'b0 : orig_times[6];
                    eff_times[7] <= (elim_idx == 7) ? 8'b0 : orig_times[7];
                    // Reset node index
                    node_idx <= 3'b0;
                end

                COMPUTE_ELIMINATED: begin
                    if (node_idx == 0) begin
                        // Init distance for node 0 (if not eliminated)
                        dist[0] <= {8'b0, eff_times[0]};
                        node_idx <= 3'd1;
                    end else if (node_idx <= step_count) begin
                        if (node_idx < step_count) begin
                            dist[node_idx] <= {8'b0, eff_times[node_idx]} + get_max_pred_dist(node_idx, deps[node_idx], dist[0], dist[1], dist[2], dist[3], dist[4], dist[5], dist[6], dist[7]);
                        end else begin
                            current_crit <= dist[step_count - 1];
                        end
                        node_idx <= node_idx + 1;
                    end
                end

                UPDATE_MIN: begin
                    // Compare current_crit with min_time
                    if (current_crit < min_time) begin
                        min_time <= current_crit;
                    end
                    // Move to next elimination index
                    elim_idx <= elim_idx + 1;
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Helper function logic using combinational always block or continuous assignments
    // Since Verilog always block cannot call function that loops over array easily in synthesis without static unrolling,
    // we implement the max predecessor logic explicitly.
    // However, to keep the code clean and fit in one module, we can use a function if we assume indices are static,
    // or just replicate logic.
    // Since we are inside an always block, we can't use 'function' easily for array inputs in standard Verilog if not supported.
    // Let's use a separate combinational block or inline logic. 
    // To make it correct inside the sequential block, we calculate the value on the fly.
    
    // Actually, standard synthesisable Verilog often supports functions that take array inputs in SystemVerilog.
    // However, to be safe for generic Verilog and the instructions, let's use a combinational block to compute max.
    // But we are inside a sequential block. We can't define a combinational block here.
    // We will write an explicit helper logic.
    
    // Wait, I cannot declare a function inside an always block.
    // I will define the logic using a combinational wire outside, or just inline the logic for the 8 nodes explicitly inside the always block using if-else trees.
    // The prompt asks for a module. Let's try to make it modular.
    
    // Let's implement a function at the end of the module, valid in SystemVerilog.
    function automatic [15:0] get_max_pred_dist;
        input [2:0] node;
        input [7:0] mask;
        input [15:0] d0, d1, d2, d3, d4, d5, d6, d7;
        reg [15:0] max_val;
        integer i;
        begin
            max_val = 16'b0;
            // Check each bit of mask
            if (mask[0] && d0 > max_val) max_val = d0;
            if (mask[1] && d1 > max_val) max_val = d1;
            if (mask[2] && d2 > max_val) max_val = d2;
            if (mask[3] && d3 > max_val) max_val = d3;
            if (mask[4] && d4 > max_val) max_val = d4;
            if (mask[5] && d5 > max_val) max_val = d5;
            if (mask[6] && d6 > max_val) max_val = d6;
            if (mask[7] && d7 > max_val) max_val = d7;
            get_max_pred_dist = max_val;
        end
    endfunction

endmodule
