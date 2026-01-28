module spy_message_minimizer #(
    parameter N = 8,
    parameter DATA_WIDTH = N,
    parameter ADJ_WIDTH = N*N
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] enemy_mask,
    input wire [ADJ_WIDTH-1:0] adj_matrix,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_REACH = 3'd1;
    localparam [2:0] FLOYD_WARSHALL = 3'd2;
    localparam [2:0] COMPUTE_SAFE = 3'd3;
    localparam [2:0] ENUMERATE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Internal registers
    reg [DATA_WIDTH-1:0] reach [0:N-1];
    reg [DATA_WIDTH-1:0] safe;
    reg [DATA_WIDTH-1:0] good_mask;
    reg [N-1:0] subset;
    reg [7:0] min_cost;
    reg [7:0] current_cost;
    reg [DATA_WIDTH-1:0] covered;
    reg [DATA_WIDTH-1:0] uncovered;
    reg [DATA_WIDTH-1:0] reach_row_i;

    // Counters
    reg [2:0] k_idx;
    reg [2:0] i_idx;
    reg [2:0] j_idx;
    reg [2:0] idx;
    reg [2:0] bit_pos;

    // Helper function for popcount (combinational)
    function automatic [3:0] popcount(input [N-1:0] val);
        integer b;
        begin
            popcount = 4'd0;
            for (b = 0; b < N; b = b + 1) begin
                if (val[b]) popcount = popcount + 4'd1;
            end
        end
    endfunction

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT_REACH;
            
            INIT_REACH: next_state = FLOYD_WARSHALL;
            
            FLOYD_WARSHALL: begin
                if (k_idx == N-1 && i_idx == N-1 && j_idx == N-1)
                    next_state = COMPUTE_SAFE;
                else
                    next_state = FLOYD_WARSHALL;
            end
            
            COMPUTE_SAFE: next_state = ENUMERATE;
            
            ENUMERATE: begin
                if (subset == {N{1'b1}})
                    next_state = DONE_STATE;
                else
                    next_state = ENUMERATE;
            end
            
            DONE_STATE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE_STATE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Main state machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            // Initialize all regs
            min_cost <= 8'd255;
            subset <= 0;
            k_idx <= 3'd0;
            i_idx <= 3'd0;
            j_idx <= 3'd0;
            idx <= 3'd0;
            bit_pos <= 3'd0;
            for (int r = 0; r < N; r = r + 1) reach[r] <= 0;
            safe <= 0;
            good_mask <= 0;
            covered <= 0;
            uncovered <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        min_cost <= 8'd255;
                        subset <= 0;
                        good_mask <= ~enemy_mask;
                    end
                end

                INIT_REACH: begin
                    // Initialize reachability matrix from adjacency matrix
                    for (int r = 0; r < N; r = r + 1) begin
                        reach[r] <= adj_matrix[r*N +: N];
                    end
                    k_idx <= 3'd0;
                    i_idx <= 3'd0;
                    j_idx <= 3'd0;
                end

                FLOYD_WARSHALL: begin
                    // Perform Floyd-Warshall: one update per cycle
                    if (reach[i_idx][k_idx] && reach[k_idx][j_idx]) begin
                        reach[i_idx][j_idx] <= 1'b1;
                    end
                    
                    // Increment indices
                    if (j_idx < N-1) begin
                        j_idx <= j_idx + 3'd1;
                    end else begin
                        j_idx <= 3'd0;
                        if (i_idx < N-1) begin
                            i_idx <= i_idx + 3'd1;
                        end else begin
                            i_idx <= 3'd0;
                            if (k_idx < N-1) begin
                                k_idx <= k_idx + 3'd1;
                            end
                            // When loops finish, k_idx will be N-1 and last update is done
                        end
                    end
                end

                COMPUTE_SAFE: begin
                    // Compute safe mask: node is safe if not enemy and has no path to enemy
                    safe <= 0;
                    for (int s = 0; s < N; s = s + 1) begin
                        if (!enemy_mask[s]) begin
                            safe[s] <= 1'b1;
                            for (int t = 0; t < N; t = t + 1) begin
                                if (enemy_mask[t] && reach[s][t]) safe[s] <= 1'b0;
                            end
                        end
                    end
                end

                ENUMERATE: begin
                    // Iterate through subsets
                    if (subset != {N{1'b1}}) begin
                        subset <= subset + 1;
                        
                        // Check if subset is valid (only safe nodes)
                        if ((subset & ~safe) == 0) begin
                            // Compute covered set
                            covered <= 0;
                            for (int i = 0; i < N; i = i + 1) begin
                                if (subset[i]) covered <= covered | reach[i];
                            end
                            // Compute uncovered
                            uncovered <= good_mask & ~covered;
                            // Compute cost
                            current_cost <= popcount(subset) + popcount(good_mask & ~covered);
                            // Update min
                            if (popcount(subset) + popcount(good_mask & ~covered) < min_cost) begin
                                min_cost <= popcount(subset) + popcount(good_mask & ~covered);
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    result <= min_cost;
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule