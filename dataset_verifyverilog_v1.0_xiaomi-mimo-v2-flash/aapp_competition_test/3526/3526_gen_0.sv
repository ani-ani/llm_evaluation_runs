module CountValidSequences(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [4:0] m,
    input [31:0] hint_l [0:31],
    input [31:0] hint_r [0:31],
    input [31:0] hint_type,
    input [31:0] hint_valid,
    output reg [15:0] result,
    output reg done
);

    // Constants
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_UNION = 4'd1;
    localparam [3:0] PROCESS_SAME = 4'd2;
    localparam [3:0] CHECK_DIFF = 4'd3;
    localparam [3:0] COUNT_COMPONENTS = 4'd4;
    localparam [3:0] CALC_RESULT = 4'd5;
    localparam [3:0] FINISH = 4'd6;
    
    localparam [31:0] MOD = 32'd1000000007;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // State and signals
    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    reg [3:0] i, j, k;
    reg [4:0] idx;
    
    // Union-Find arrays (0-indexed for n nodes)
    reg [3:0] parent [0:15];
    reg [3:0] find_root;
    reg [3:0] temp_parent;
    
    // Conflict matrix (16x16)
    reg [15:0] conflict [0:15];
    
    // Component counting
    reg [15:0] seen_roots;
    reg [3:0] component_count;
    
    // Result calculation
    reg [15:0] pow2;
    reg [31:0] calc_temp;
    reg [1:0] calc_step;
    
    // Internal control
    reg processing_started;
    reg conflict_detected;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            idx <= 5'd0;
            find_root <= 4'd0;
            temp_parent <= 4'd0;
            component_count <= 4'd0;
            pow2 <= 16'd1;
            calc_temp <= 32'd0;
            calc_step <= 2'd0;
            processing_started <= 1'b0;
            conflict_detected <= 1'b0;
            seen_roots <= 16'd0;
            // Initialize parent array
            parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3;
            parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; parent[7] <= 4'd7;
            parent[8] <= 4'd8; parent[9] <= 4'd9; parent[10] <= 4'd10; parent[11] <= 4'd11;
            parent[12] <= 4'd12; parent[13] <= 4'd13; parent[14] <= 4'd14; parent[15] <= 4'd15;
            // Initialize conflict matrix
            conflict[0] <= 16'd0; conflict[1] <= 16'd0; conflict[2] <= 16'd0; conflict[3] <= 16'd0;
            conflict[4] <= 16'd0; conflict[5] <= 16'd0; conflict[6] <= 16'd0; conflict[7] <= 16'd0;
            conflict[8] <= 16'd0; conflict[9] <= 16'd0; conflict[10] <= 16'd0; conflict[11] <= 16'd0;
            conflict[12] <= 16'd0; conflict[13] <= 16'd0; conflict[14] <= 16'd0; conflict[15] <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    processing_started <= 1'b0;
                    conflict_detected <= 1'b0;
                    seen_roots <= 16'd0;
                    component_count <= 4'd0;
                    pow2 <= 16'd1;
                    calc_temp <= 32'd0;
                    calc_step <= 2'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    idx <= 5'd0;
                    // Reset parent to identity for n nodes
                    if (start && n > 4'd0 && n <= 4'd16) begin
                        state <= INIT_UNION;
                        // Initialize parent array for the valid range
                        case (n)
                            4'd1: begin parent[0] <= 4'd0; end
                            4'd2: begin parent[0] <= 4'd0; parent[1] <= 4'd1; end
                            4'd3: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; end
                            4'd4: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; end
                            4'd5: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; parent[4] <= 4'd4; end
                            4'd6: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; parent[4] <= 4'd4; parent[5] <= 4'd5; end
                            4'd7: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; end
                            4'd8: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; parent[7] <= 4'd7; end
                            4'd9: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; parent[7] <= 4'd7; parent[8] <= 4'd8; end
                            4'd10: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; parent[7] <= 4'd7; parent[8] <= 4'd8; parent[9] <= 4'd9; end
                            4'd11: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; parent[7] <= 4'd7; parent[8] <= 4'd8; parent[9] <= 4'd9; parent[10] <= 4'd10; end
                            4'd12: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; parent[7] <= 4'd7; parent[8] <= 4'd8; parent[9] <= 4'd9; parent[10] <= 4'd10; parent[11] <= 4'd11; end
                            4'd13: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; parent[7] <= 4'd7; parent[8] <= 4'd8; parent[9] <= 4'd9; parent[10] <= 4'd10; parent[11] <= 4'd11; parent[12] <= 4'd12; end
                            4'd14: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; parent[7] <= 4'd7; parent[8] <= 4'd8; parent[9] <= 4'd9; parent[10] <= 4'd10; parent[11] <= 4'd11; parent[12] <= 4'd12; parent[13] <= 4'd13; end
                            4'd15: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; parent[7] <= 4'd7; parent[8] <= 4'd8; parent[9] <= 4'd9; parent[10] <= 4'd10; parent[11] <= 4'd11; parent[12] <= 4'd12; parent[13] <= 4'd13; parent[14] <= 4'd14; end
                            4'd16: begin parent[0] <= 4'd0; parent[1] <= 4'd1; parent[2] <= 4'd2; parent[3] <= 4'd3; parent[4] <= 4'd4; parent[5] <= 4'd5; parent[6] <= 4'd6; parent[7] <= 4'd7; parent[8] <= 4'd8; parent[9] <= 4'd9; parent[10] <= 4'd10; parent[11] <= 4'd11; parent[12] <= 4'd12; parent[13] <= 4'd13; parent[14] <= 4'd14; parent[15] <= 4'd15; end
                            default: begin end
                        endcase
                        // Reset conflict matrix
                        conflict[0] <= 16'd0; conflict[1] <= 16'd0; conflict[2] <= 16'd0; conflict[3] <= 16'd0;
                        conflict[4] <= 16'd0; conflict[5] <= 16'd0; conflict[6] <= 16'd0; conflict[7] <= 16'd0;
                        conflict[8] <= 16'd0; conflict[9] <= 16'd0; conflict[10] <= 16'd0; conflict[11] <= 16'd0;
                        conflict[12] <= 16'd0; conflict[13] <= 16'd0; conflict[14] <= 16'd0; conflict[15] <= 16'd0;
                    end
                end
                
                INIT_UNION: begin
                    // Clear conflict matrix and prepare for processing
                    conflict[0] <= 16'd0; conflict[1] <= 16'd0; conflict[2] <= 16'd0; conflict[3] <= 16'd0;
                    conflict[4] <= 16'd0; conflict[5] <= 16'd0; conflict[6] <= 16'd0; conflict[7] <= 16'd0;
                    conflict[8] <= 16'd0; conflict[9] <= 16'd0; conflict[10] <= 16'd0; conflict[11] <= 16'd0;
                    conflict[12] <= 16'd0; conflict[13] <= 16'd0; conflict[14] <= 16'd0; conflict[15] <= 16'd0;
                    idx <= 5'd0;
                    state <= PROCESS_SAME;
                end
                
                PROCESS_SAME: begin
                    if (idx < m && idx < 5'd32) begin
                        if (hint_valid[idx] && hint_type[idx] == 1'b0) begin
                            // Union constraint: l and r (convert to 0-indexed)
                            // Find root of l-1
                            i <= hint_l[idx] - 4'd1;
                            state <= CALC_RESULT; // Temporary state for find
                            calc_step <= 2'd0; // Start find
                        end else begin
                            idx <= idx + 5'd1;
                        end
                    end else begin
                        idx <= 5'd0;
                        state <= CHECK_DIFF;
                    end
                end
                
                CHECK_DIFF: begin
                    if (idx < m && idx < 5'd32) begin
                        if (hint_valid[idx] && hint_type[idx] == 1'b1) begin
                            // Different constraint: build conflict matrix
                            // For all u,v in [l, r], set conflict[u][v] = 1
                            i <= hint_l[idx] - 4'd1;
                            state <= FINISH; // Use finish as temp for inner loop
                            calc_step <= 2'd1; // Build conflicts
                        end else begin
                            idx <= idx + 5'd1;
                        end
                    end else begin
                        // Check conflicts in conflict matrix for same component
                        i <= 4'd0;
                        state <= COUNT_COMPONENTS;
                    end
                end
                
                COUNT_COMPONENTS: begin
                    if (i < n) begin
                        // Check conflict matrix for i and j in same component
                        if (conflict[i][i] == 1'b1) begin
                            conflict_detected <= 1'b1;
                        end
                        // Check diagonal (conflict with self)
                        i <= i + 4'd1;
                    end else begin
                        if (conflict_detected) begin
                            result <= 16'd0;
                            state <= FINISH;
                            calc_step <= 2'd3;
                        end else begin
                            // Count components
                            i <= 4'd0;
                            seen_roots <= 16'd0;
                            component_count <= 4'd0;
                            state <= FINISH;
                            calc_step <= 2'd2; // Count components
                        end
                    end
                end
                
                CALC_RESULT: begin
                    case (calc_step)
                        2'd0: begin // Find root for l
                            if (parent[i] != i) begin
                                find_root <= parent[i];
                                i <= parent[i];
                                state <= CALC_RESULT;
                                calc_step <= 2'd0;
                            end else begin
                                // Found root of l
                                find_root <= i;
                                // Now find root of r
                                i <= hint_l[idx] - 4'd1; // l-1
                                calc_step <= 2'd1; // Find r root
                            end
                        end
                        2'd1: begin // Find root for r
                            if (parent[i] != i) begin
                                find_root <= parent[i];
                                i <= parent[i];
                                state <= CALC_RESULT;
                                calc_step <= 2'd1;
                            end else begin
                                // Found root of r
                                if (i != find_root) begin
                                    // Union: make i child of find_root
                                    parent[i] <= find_root;
                                end
                                idx <= idx + 5'd1;
                                state <= PROCESS_SAME;
                            end
                        end
                        default: begin end
                    endcase
                end
                
                FINISH: begin
                    case (calc_step)
                        2'd1: begin // Build conflict matrix for hint
                            if (i < hint_r[idx] - 4'd1) begin // u in [l, r]
                                j <= i + 4'd1;
                                state <= FINISH;
                                calc_step <= 2'd2; // Inner loop
                            end else begin
                                idx <= idx + 5'd1;
                                state <= CHECK_DIFF;
                            end
                        end
                        2'd2: begin // Inner loop for conflicts
                            if (j < hint_r[idx]) begin // v in [u+1, r]
                                // Set conflict[u][v] and conflict[v][u]
                                conflict[i][j] <= 1'b1;
                                conflict[j][i] <= 1'b1;
                                j <= j + 4'd1;
                            end else begin
                                i <= i + 4'd1;
                                state <= FINISH;
                                calc_step <= 2'd1;
                            end
                        end
                        2'd3: begin // Count components
                            if (i < n) begin
                                // Find root of i
                                temp_parent <= i;
                                state <= FINISH;
                                calc_step <= 2'd4; // Find root
                            end else begin
                                // Calculate 2^component_count mod MOD
                                pow2 <= 16'd1;
                                i <= 4'd0;
                                calc_temp <= 32'd1;
                                state <= FINISH;
                                calc_step <= 2'd5; // Calculate power
                            end
                        end
                        2'd4: begin // Find root of temp_parent
                            if (parent[temp_parent] != temp_parent) begin
                                temp_parent <= parent[temp_parent];
                            end else begin
                                // Check if seen before
                                if (!seen_roots[temp_parent]) begin
                                    seen_roots[temp_parent] <= 1'b1;
                                    component_count <= component_count + 4'd1;
                                end
                                i <= i + 4'd1;
                                state <= FINISH;
                                calc_step <= 2'd3;
                            end
                        end
                        2'd5: begin // Calculate 2^component_count
                            if (i < component_count) begin
                                calc_temp <= (calc_temp * 32'd2) % MOD;
                                i <= i + 4'd1;
                            end else begin
                                result <= calc_temp[15:0];
                                done <= 1'b1;
                                state <= IDLE;
                            end
                        end
                        default: begin end
                    endcase
                end
                
                default: state <= IDLE;
            endcase
            
            // Cycle counter
            if (state != IDLE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    // Timeout protection
                    if (state != FINISH) begin
                        result <= 16'd0;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
            end
        end
    end

endmodule