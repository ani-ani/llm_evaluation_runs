module TreeSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n_in,
    input wire [4:0] c_in [0:15],
    output reg result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] SORT          = 4'd1;
    localparam [3:0] CHECK_ROOT    = 4'd2;
    localparam [3:0] CHECK_TWOS    = 4'd3;
    localparam [3:0] SEARCH_PREP   = 4'd4;
    localparam [3:0] SEARCH_CHILD  = 4'd5;
    localparam [3:0] SEARCH_ATTACH = 4'd6;
    localparam [3:0] VALIDATE      = 4'd7;
    localparam [3:0] FINISH        = 4'd8;

    // Internal registers
    reg [3:0] state, next_state;
    reg [3:0] idx, next_idx;
    reg [3:0] jdx, next_jdx;
    reg [3:0] kdx, next_kdx;
    reg [4:0] n_reg;
    reg [4:0] sorted_c [0:15];
    reg [4:0] rem [0:15];
    reg [3:0] child_count [0:15];
    reg [15:0] mask [0:15];
    reg [15:0] all_nodes_mask;
    reg search_valid;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd30;

    // Temporary variables for combinational logic
    reg [3:0] temp_idx;
    reg [3:0] temp_jdx;
    reg [4:0] temp_c;
    reg [4:0] temp_rem;
    reg [15:0] temp_mask;
    reg [3:0] best_child;
    reg attach_found;
    reg all_rem_zero;
    reg child_ge_2;

    integer i;

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            jdx <= 4'd0;
            kdx <= 4'd0;
            n_reg <= 5'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
                sorted_c[i] <= 5'd0;
                rem[i] <= 5'd0;
                child_count[i] <= 4'd0;
                mask[i] <= 16'd0;
            end
            all_nodes_mask <= 16'd0;
            search_valid <= 1'b0;
        end else begin
            state <= next_state;
            idx <= next_idx;
            jdx <= next_jdx;
            kdx <= next_kdx;
            cycle_count <= (state == IDLE) ? 5'd0 : (cycle_count + 5'd1);
            
            case (state)
                IDLE: begin
                    result <= 1'b0;
                    done <= 1'b0;
                    n_reg <= n_in;
                    // Copy and sort input
                    for (i = 0; i < 16; i = i + 1) begin
                        sorted_c[i] <= c_in[i];
                    end
                    all_nodes_mask <= (n_in == 5'd16) ? 16'hFFFF : ((1 << n_in) - 1);
                end
                
                SORT: begin
                    // Bubble sort in hardware
                    if (idx < n_reg - 1 && jdx < n_reg - 1 - idx) begin
                        if (sorted_c[jdx] < sorted_c[jdx + 1]) begin
                            temp_c <= sorted_c[jdx];
                            sorted_c[jdx] <= sorted_c[jdx + 1];
                            sorted_c[jdx + 1] <= temp_c;
                        end
                    end
                end
                
                CHECK_ROOT: begin
                    // Result set in combinational logic
                    if (sorted_c[0] != n_reg) begin
                        search_valid <= 1'b0;
                    end else begin
                        search_valid <= 1'b1;
                    end
                end
                
                CHECK_TWOS: begin
                    // Check for c[i] == 2
                    if (sorted_c[idx] == 5'd2 && idx < n_reg) begin
                        search_valid <= 1'b0;
                    end
                end
                
                SEARCH_PREP: begin
                    // Initialize for search
                    for (i = 0; i < 16; i = i + 1) begin
                        rem[i] <= (i < n_reg) ? (sorted_c[i] - 5'd1) : 5'd0;
                        child_count[i] <= 4'd0;
                        mask[i] <= (i < n_reg) ? (16'd1 << i) : 16'd0;
                    end
                end
                
                SEARCH_CHILD: begin
                    // Start search from node 1 (skip root at 0)
                    if (idx == 4'd0) begin
                        idx <= 4'd1;
                    end
                    // child_count tracking
                end
                
                SEARCH_ATTACH: begin
                    if (attach_found) begin
                        // Attach child (idx) to parent (best_child)
                        rem[best_child] <= rem[best_child] - sorted_c[idx];
                        child_count[best_child] <= child_count[best_child] + 4'd1;
                        mask[best_child] <= mask[best_child] | mask[idx];
                        idx <= idx + 4'd1;
                    end else begin
                        // Backtrack
                        if (idx > 4'd1) begin
                            idx <= idx - 4'd1;
                            // Find which node had this child
                            for (i = 0; i < 16; i = i + 1) begin
                                if (mask[i][idx]) begin
                                    rem[i] <= rem[i] + sorted_c[idx];
                                    child_count[i] <= child_count[i] - 4'd1;
                                    mask[i] <= mask[i] & ~(16'd1 << idx);
                                end
                            end
                            // Reset child mask
                            mask[idx] <= 16'd1 << idx;
                            search_valid <= (idx == 4'd1) ? 1'b0 : search_valid;
                        end else begin
                            search_valid <= 1'b0;
                        end
                    end
                end
                
                VALIDATE: begin
                    // Check all remaining are leaves
                    all_rem_zero <= 1'b1;
                    child_ge_2 <= 1'b1;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n_reg) begin
                            if (rem[i] != 5'd0) begin
                                all_rem_zero <= 1'b0;
                            end
                            if (child_count[i] > 4'd0 && child_count[i] < 4'd2) begin
                                child_ge_2 <= 1'b0;
                            end
                        end
                    end
                    if (all_rem_zero && child_ge_2 && idx == n_reg) begin
                        search_valid <= 1'b1;
                    end else begin
                        search_valid <= 1'b0;
                    end
                end
                
                FINISH: begin
                    result <= search_valid;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        next_idx = idx;
        next_jdx = jdx;
        next_kdx = kdx;
        attach_found = 1'b0;
        best_child = 4'd0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SORT;
                    next_idx = 4'd0;
                    next_jdx = 4'd0;
                end
            end
            
            SORT: begin
                if (idx < n_reg - 1) begin
                    if (jdx < n_reg - 1 - idx) begin
                        next_jdx = jdx + 4'd1;
                    end else begin
                        next_jdx = 4'd0;
                        next_idx = idx + 4'd1;
                    end
                end else begin
                    next_state = CHECK_ROOT;
                    next_idx = 4'd0;
                end
            end
            
            CHECK_ROOT: begin
                next_state = CHECK_TWOS;
                next_idx = 4'd0;
            end
            
            CHECK_TWOS: begin
                if (idx < n_reg) begin
                    next_idx = idx + 4'd1;
                end else begin
                    if (search_valid && n_reg > 1) begin
                        next_state = SEARCH_PREP;
                    end else if (search_valid) begin
                        next_state = FINISH;
                    end else begin
                        next_state = FINISH;
                    end
                end
            end
            
            SEARCH_PREP: begin
                if (n_reg > 1) begin
                    next_state = SEARCH_CHILD;
                    next_idx = 4'd0;
                end else begin
                    next_state = FINISH;
                end
            end
            
            SEARCH_CHILD: begin
                if (idx >= n_reg) begin
                    next_state = VALIDATE;
                end else begin
                    next_state = SEARCH_ATTACH;
                    next_kdx = 4'd0;
                end
            end
            
            SEARCH_ATTACH: begin
                // Try to attach node idx to parent kdx
                if (kdx < idx) begin
                    // Check if kdx has enough remaining capacity
                    if (rem[kdx] >= sorted_c[idx]) begin
                        // Check if this would be the first child and would fill capacity
                        if (!(rem[kdx] == sorted_c[idx] && child_count[kdx] == 4'd0)) begin
                            attach_found = 1'b1;
                            best_child = kdx;
                            next_state = SEARCH_CHILD;
                        end
                    end
                    if (!attach_found) begin
                        next_kdx = kdx + 4'd1;
                    end
                end else begin
                    // Tried all parents, backtrack
                    if (idx > 4'd1) begin
                        // Find which node has this child
                        next_kdx = 4'd0;
                        next_idx = idx - 4'd1;
                        next_state = SEARCH_CHILD;
                    end else begin
                        next_state = FINISH;
                    end
                end
            end
            
            VALIDATE: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Cycle timeout
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            next_state = FINISH;
        end
    end

endmodule