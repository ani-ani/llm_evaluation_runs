module below_zero (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] operations [0:7],
    input wire [2:0] valid_ops,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg signed [11:0] balance;
    reg [2:0] op_index;
    reg result_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            balance <= 12'sd0;
            op_index <= 3'd0;
            result_reg <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= result_reg;
                    if (start) begin
                        balance <= 12'sd0;
                        op_index <= 3'd0;
                        // Keep result_reg sticky
                        state <= PROCESSING;
                    end
                end
                
                PROCESSING: begin
                    // Process operation
                    if (op_index < valid_ops) begin
                        balance <= balance + $signed(operations[op_index]);
                        
                        // Check if balance below zero
                        if (balance + $signed(operations[op_index]) < 12'sd0) begin
                            result_reg <= 1'b1;
                        end
                        
                        op_index <= op_index + 3'd1;
                        
                        // Check if last operation
                        if (op_index + 3'd1 >= valid_ops) begin
                            state <= DONE_STATE;
                        end
                    end else begin
                        // No operations or done
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= result_reg;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    balance <= 12'sd0;
                    op_index <= 3'd0;
                    result_reg <= 1'b0;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule