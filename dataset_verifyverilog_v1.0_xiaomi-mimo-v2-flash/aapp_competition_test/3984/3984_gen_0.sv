module StringGameSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire char_end,
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESS   = 2'd1;
    localparam [1:0] FINISH    = 2'd2;
    localparam [1:0] DONE_WAIT = 2'd3;
    
    // Internal registers
    reg [1:0] state;
    reg [7:0] current_min;
    reg [3:0] position_counter;  // 0-15 for up to 16 characters
    reg [15:0] result_reg;
    reg done_pulse;
    reg processing_started;
    
    // Combinational logic for next state
    reg [1:0] next_state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            result_reg <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
            current_min <= 8'h7F;  // Max ASCII value
            position_counter <= 4'd0;
            done_pulse <= 1'b0;
            processing_started <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    done_pulse <= 1'b0;
                    processing_started <= 1'b0;
                    current_min <= 8'h7F;
                    position_counter <= 4'd0;
                    result_reg <= 16'd0;
                    
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    if (char_valid) begin
                        // Determine if Ann or Mike wins at this position
                        if (char_in > current_min) begin
                            // Ann wins (set bit to 1)
                            result_reg[position_counter] <= 1'b1;
                        end else begin
                            // Mike wins (set bit to 0)
                            result_reg[position_counter] <= 1'b0;
                        end
                        
                        // Update current_min for next position
                        if (char_in < current_min) begin
                            current_min <= char_in;
                        end
                        
                        // Increment position counter
                        position_counter <= position_counter + 4'd1;
                    end
                    
                    // Check for end of string
                    if (char_end) begin
                        // If no chars were processed (empty string), position_counter stays 0
                        state <= FINISH;
                    end else if (position_counter >= 4'd15) begin
                        // Maximum string length reached (16 chars)
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Transfer final result to output
                    result <= result_reg;
                    valid <= 1'b1;
                    done_pulse <= 1'b1;
                    state <= DONE_WAIT;
                end
                
                DONE_WAIT: begin
                    // Keep done high for 1 cycle, then go to idle
                    done <= done_pulse;
                    done_pulse <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
endmodule