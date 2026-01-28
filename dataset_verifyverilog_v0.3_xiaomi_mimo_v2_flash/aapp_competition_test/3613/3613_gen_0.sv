module find_min_T(
    input clk,
    input rst_n,
    input start,
    input [1:0] teacher [0:5],
    input [2:0] pref [0:5][0:4],
    output reg [3:0] T,
    output reg done
);

// Parameters
localparam [3:0] N = 4'd6;
localparam [3:0] MAX_T = 4'd5;
localparam [2:0] LOG_N = 3'd3;

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] COMPUTE_MASKS = 4'd1;
localparam [3:0] ENUMERATE = 4'd2;
localparam [3:0] CHECK = 4'd3;
localparam [3:0] FOUND = 4'd4;
localparam [3:0] INCREMENT_T = 4'd5;
localparam [3:0] DONE = 4'd6;

// Internal registers
reg [3:0] state;
reg [3:0] next_state;
reg [3:0] T_reg;
reg [2:0] i; // for loops
reg [2:0] pos;
reg [2:0] j;
reg [2:0] k;
reg [5:0] assignment_idx; // 0 to 728
reg [1:0] assigned_teacher [0:5];
reg [1:0] stored_teacher [0:5];
reg [2:0] stored_pref [0:5][0:4];
reg [5:0] mask [0:5]; // 6 kids, each mask 6 bits
reg [5:0] temp_mask;
reg valid_check;
reg [1:0] carry; // for base-3 increment
reg [2:0] digit;
reg [2:0] digit_idx;
reg done_pulse;

// Temporary variables for combinational logic
integer ci, cj, ck;
reg temp_valid;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        T_reg <= 4'd0;
        done <= 1'b0;
        assignment_idx <= 6'd0;
        for (ci = 0; ci < 6; ci = ci + 1) begin
            stored_teacher[ci] <= 2'd0;
            for (ck = 0; ck < 5; ck = ck + 1) begin
                stored_pref[ci][ck] <= 3'd0;
            end
            mask[ci] <= 6'd0;
            assigned_teacher[ci] <= 2'd0;
        end
        i <= 3'd0;
        pos <= 3'd0;
        j <= 3'd0;
        k <= 3'd0;
        done_pulse <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                done_pulse <= 1'b0;
                T_reg <= 4'd0;
                assignment_idx <= 6'd0;
                if (start) begin
                    // Capture inputs
                    for (ci = 0; ci < 6; ci = ci + 1) begin
                        stored_teacher[ci] <= teacher[ci];
                        for (ck = 0; ck < 5; ck = ck + 1) begin
                            stored_pref[ci][ck] <= pref[ci][ck];
                        end
                    end
                    state <= COMPUTE_MASKS;
                    i <= 3'd0;
                    pos <= 3'd0;
                end else begin
                    state <= IDLE;
                end
            end

            COMPUTE_MASKS: begin
                if (i < N) begin
                    if (pos < T_reg) begin
                        // Set bit in mask
                        mask[i][ stored_pref[i][pos] ] <= 1'b1;
                        pos <= pos + 3'd1;
                    end else begin
                        // Move to next kid
                        pos <= 3'd0;
                        i <= i + 3'd1;
                    end
                end else begin
                    // All masks computed
                    assignment_idx <= 6'd0;
                    state <= ENUMERATE;
                end
            end

            ENUMERATE: begin
                // Initialize assigned_teacher from current assignment_idx
                // Convert base-10 to base-3 for all 6 digits
                // We reset assigned_teacher first
                for (ci = 0; ci < 6; ci = ci + 1) begin
                    assigned_teacher[ci] <= 2'd0;
                end
                // Then decode
                // This is a simplification; actual decoding needs logic.
                // We will decode in a separate step or combinational block.
                // For now, we assume a helper block or sequential decoding.
                // Let's do sequential decoding.
                k <= 3'd0; // digit index
                j <= 3'd0; // temp value
                j <= assignment_idx[5:0]; // copy
                state <= CHECK;
            end

            CHECK: begin
                // Check validity of current assignment
                temp_valid = 1'b1;
                // Check rule a
                for (ci = 0; ci < 6; ci = ci + 1) begin
                    if (assigned_teacher[ci] == stored_teacher[ci]) begin
                        temp_valid = 1'b0;
                    end
                end
                // Check rule b
                if (temp_valid) begin
                    for (ci = 0; ci < 6; ci = ci + 1) begin
                        for (cj = ci + 1; cj < 6; cj = cj + 1) begin
                            if (assigned_teacher[ci] == assigned_teacher[cj]) begin
                                if (!(mask[ci][cj] && mask[cj][ci])) begin
                                    temp_valid = 1'b0;
                                end
                            end
                        end
                    end
                end
                
                if (temp_valid) begin
                    state <= FOUND;
                end else begin
                    // Increment assignment
                    // Base-3 increment
                    carry = 1'b1;
                    for (digit_idx = 0; digit_idx < 6; digit_idx = digit_idx + 1) begin
                        if (carry) begin
                            if (assigned_teacher[digit_idx] < 2) begin
                                assigned_teacher[digit_idx] <= assigned_teacher[digit_idx] + 2'd1;
                                carry = 1'b0;
                            end else begin
                                assigned_teacher[digit_idx] <= 2'd0;
                                carry = 1'b1;
                            end
                        end
                    end
                    if (carry) begin
                        // Overflow, all assignments checked
                        state <= INCREMENT_T;
                    end else begin
                        state <= CHECK; // Stay in CHECK to re-evaluate
                    end
                end
            end

            FOUND: begin
                T_reg <= T_reg;
                done_pulse <= 1'b1;
                state <= DONE;
            end

            INCREMENT_T: begin
                if (T_reg < MAX_T) begin
                    T_reg <= T_reg + 4'd1;
                    // Reset masks for next T
                    for (ci = 0; ci < 6; ci = ci + 1) begin
                        mask[ci] <= 6'd0;
                    end
                    i <= 3'd0;
                    pos <= 3'd0;
                    state <= COMPUTE_MASKS;
                end else begin
                    // Should not happen if solution exists
                    T_reg <= MAX_T;
                    done_pulse <= 1'b1;
                    state <= DONE;
                end
            end

            DONE: begin
                T <= T_reg;
                done <= done_pulse;
                done_pulse <= 1'b0; // Pulse low after one cycle
                state <= DONE; // Stay here until reset
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// Combinational block to decode assignment_idx to assigned_teacher
always @(*) begin
    // Initialize
    for (ci = 0; ci < 6; ci = ci + 1) begin
        assigned_teacher[ci] = 2'd0;
    end
    // Decode
    integer temp_val;
    temp_val = assignment_idx;
    for (ci = 0; ci < 6; ci = ci + 1) begin
        assigned_teacher[ci] = temp_val % 3;
        temp_val = temp_val / 3;
    end
end

endmodule