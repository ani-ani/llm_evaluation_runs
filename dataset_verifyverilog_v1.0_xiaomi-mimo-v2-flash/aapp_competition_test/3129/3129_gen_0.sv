module hay_bale_sorter(
    input clk,
    input rst_n,
    input start,
    input s_0, s_1, s_2, s_3, s_4, s_5, s_6, s_7,
    output reg [7:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORTING = 3'd1;
    localparam [2:0] CHECKING = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] seq_reg;
    reg [7:0] seq_next;
    reg [7:0] result_reg;
    reg [7:0] result_next;
    reg [2:0] idx;
    reg [2:0] idx_next;
    reg [7:0] cycle_count;
    reg [7:0] cycle_count_next;
    reg changed;
    reg changed_next;
    reg [1:0] bits_0, bits_1, bits_2;
    reg [1:0] bit_count;
    reg [2:0] i;
    
    // Output assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            result <= result_reg;
            done <= (state == DONE_STATE);
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        seq_next = seq_reg;
        result_next = result_reg;
        idx_next = idx;
        cycle_count_next = cycle_count;
        changed_next = changed;
        
        case (state)
            IDLE: begin
                if (start) begin
                    // Load sequence
                    seq_next = {s_7, s_6, s_5, s_4, s_3, s_2, s_1, s_0};
                    result_next = 8'd0;
                    idx_next = 3'd0;
                    cycle_count_next = 8'd0;
                    changed_next = 1'b0;
                    next_state = SORTING;
                end
            end
            
            SORTING: begin
                // Count 1s in current window
                bit_count = seq_reg[idx] + seq_reg[idx + 1] + seq_reg[idx + 2];
                
                // Check if sorting needed
                if (bit_count == 1'b1) begin
                    // Move 1 to position idx+2
                    seq_next = seq_reg;
                    seq_next[idx] = 1'b0;
                    seq_next[idx + 1] = 1'b0;
                    seq_next[idx + 2] = 1'b1;
                    result_next = result_reg + 8'd1;
                    changed_next = 1'b1;
                end else if (bit_count == 2'd2) begin
                    // Move 0 to position idx
                    seq_next = seq_reg;
                    seq_next[idx] = 1'b0;
                    seq_next[idx + 1] = 1'b1;
                    seq_next[idx + 2] = 1'b1;
                    result_next = result_reg + 8'd1;
                    changed_next = 1'b1;
                end
                // If bit_count == 0 or 3, no change
                
                if (idx < 3'd5) begin
                    idx_next = idx + 3'd1;
                end else begin
                    // Completed a full pass
                    idx_next = 3'd0;
                    next_state = CHECKING;
                end
            end
            
            CHECKING: begin
                cycle_count_next = cycle_count + 8'd1;
                
                if (changed || cycle_count >= 8'd64) begin
                    // More work to do or safety timeout
                    if (changed) begin
                        changed_next = 1'b0;
                        next_state = SORTING;
                    end else begin
                        // Safety timeout reached
                        next_state = DONE_STATE;
                    end
                end else begin
                    // No changes in last pass, sequence is sorted
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                // Stay here until next start
                if (start) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            seq_reg <= 8'd0;
            result_reg <= 8'd0;
            idx <= 3'd0;
            cycle_count <= 8'd0;
            changed <= 1'b0;
        end else begin
            state <= next_state;
            seq_reg <= seq_next;
            result_reg <= result_next;
            idx <= idx_next;
            cycle_count <= cycle_count_next;
            changed <= changed_next;
        end
    end
endmodule