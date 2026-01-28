module unique_element_checker (
  input clk,
  input rst_n,
  input start,
  input [7:0] arr [0:15],
  input [3:0] len,
  output reg result,
  output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Registers
    reg [1:0] state, next_state;
    reg [3:0] index_reg, next_index_reg;
    reg [7:0] reference, next_reference;
    reg next_result;
    reg next_done;
    
    // Combinational logic for next state
    always @(*) begin
        // Default values
        next_state = state;
        next_index_reg = index_reg;
        next_reference = reference;
        next_result = result;
        next_done = 1'b0;
        
        case (state)
            IDLE: begin
                next_index_reg = 4'd0;
                next_done = 1'b0;
                if (start) begin
                    next_state = COMPARE;
                    // Store first element as reference
                    next_reference = arr[0];
                    next_index_reg = 4'd1;
                    // Default: result = 1 (will be 0 if mismatch found)
                    next_result = 1'b1;
                end
            end
            
            COMPARE: begin
                if (index_reg < len) begin
                    // Compare current element with reference
                    if (arr[index_reg] != reference) begin
                        next_result = 1'b0;
                        next_state = DONE_STATE;
                    end else begin
                        // Continue comparing
                        next_index_reg = index_reg + 4'd1;
                        // Check if we've processed all elements
                        if (index_reg >= len - 4'd1) begin
                            next_state = DONE_STATE;
                        end
                    end
                end else begin
                    // No more elements to compare
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                next_index_reg = 4'd0;
                next_reference = 8'd0;
                next_result = 1'b0;
                next_done = 1'b0;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index_reg <= 4'd0;
            reference <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            index_reg <= next_index_reg;
            reference <= next_reference;
            result <= next_result;
            done <= next_done;
        end
    end

endmodule