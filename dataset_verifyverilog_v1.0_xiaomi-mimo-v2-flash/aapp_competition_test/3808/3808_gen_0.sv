module bracket_sequence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] seq_in,
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COUNT   = 3'd1;
    localparam [2:0] CHECK   = 3'd2;
    localparam [2:0] DONE    = 3'd3;
    localparam [2:0] ERROR   = 3'd4;
    localparam [2:0] RESET   = 3'd5;
    
    // Registers and counters
    reg [2:0] state, next_state;
    reg [3:0] idx;               // Current character index (0-15)
    reg signed [7:0] balance;    // Current prefix balance
    reg signed [7:0] min_balance; // Minimum balance encountered
    reg [7:0] open_count;        // Count of '('
    reg [7:0] close_count;       // Count of ')'
    reg [5:0] cycle_count;       // Cycle counter for timing
    localparam [5:0] MAX_CYCLES = 6'd64;
    
    // Helper: extract character from packed array
    wire [7:0] current_char;
    assign current_char = seq_in[(idx * 8) +: 8];
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            balance <= 8'sd0;
            min_balance <= 8'sd0;
            open_count <= 8'd0;
            close_count <= 8'd0;
            cycle_count <= 6'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Default assignments
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    idx <= 4'd0;
                    balance <= 8'sd0;
                    min_balance <= 8'sd0;
                    open_count <= 8'd0;
                    close_count <= 8'd0;
                    cycle_count <= 6'd0;
                    result <= 1'b0;
                    
                    if (start) begin
                        if (len == 4'd0) begin
                            // Empty sequence is correct
                            result <= 1'b1;
                            done <= 1'b1;
                            next_state <= IDLE;
                        end else begin
                            next_state <= COUNT;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COUNT: begin
                    if (idx < len) begin
                        // Check if char is '(' or ')'
                        if (current_char == 8'h28) begin // '('
                            open_count <= open_count + 8'd1;
                        end else if (current_char == 8'h29) begin // ')'
                            close_count <= close_count + 8'd1;
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        // Finished counting
                        // Check if length is even and counts equal
                        if ((len[0] == 1'b1) || (open_count != close_count)) begin
                            result <= 1'b0;
                            done <= 1'b1;
                            next_state <= IDLE;
                        end else begin
                            idx <= 4'd0;
                            balance <= 8'sd0;
                            min_balance <= 8'sd0;
                            next_state <= CHECK;
                        end
                    end
                end
                
                CHECK: begin
                    if (idx < len && cycle_count < MAX_CYCLES) begin
                        cycle_count <= cycle_count + 6'd1;
                        
                        // Update balance
                        if (current_char == 8'h28) begin // '('
                            balance <= balance + 8'sd1;
                        end else if (current_char == 8'h29) begin // ')'
                            balance <= balance - 8'sd1;
                        end
                        
                        // Update min_balance (check current and next)
                        if (current_char == 8'h29) begin
                            // Balance decreases
                            if (balance - 8'sd1 < min_balance) begin
                                min_balance <= balance - 8'sd1;
                            end
                            // Check if balance becomes -2 or less
                            if (balance - 8'sd1 < -8'sd2) begin
                                result <= 1'b0;
                                done <= 1'b1;
                                next_state <= IDLE;
                            end else begin
                                idx <= idx + 4'd1;
                                next_state <= CHECK;
                            end
                        end else begin
                            // Character is '(' - balance increases
                            if (balance + 8'sd1 < min_balance) begin
                                min_balance <= balance + 8'sd1;
                            end
                            idx <= idx + 4'd1;
                            next_state <= CHECK;
                        end
                    end else begin
                        // Finished checking
                        // Final balance must be 0 and min_balance >= -1
                        if (balance == 8'sd0 && min_balance >= -8'sd1) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                        done <= 1'b1;
                        next_state <= IDLE;
                    end
                end
                
                default: begin
                    // Reset state for safety
                    state <= IDLE;
                    idx <= 4'd0;
                    balance <= 8'sd0;
                    min_balance <= 8'sd0;
                    open_count <= 8'd0;
                    close_count <= 8'd0;
                    cycle_count <= 6'd0;
                    result <= 1'b0;
                    done <= 1'b0;
                    next_state <= IDLE;
                end
            endcase
        end
    end
endmodule