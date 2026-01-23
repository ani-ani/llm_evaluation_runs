module below_zero(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] operations [0:7],
    input [2:0] valid_ops,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Register declarations
    reg [1:0] state, next_state;
    reg signed [11:0] balance;
    reg [2:0] op_counter;
    reg [2:0] max_ops;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            balance <= 12'd0;
            result <= 1'b0;
            done <= 1'b0;
            op_counter <= 3'd0;
            max_ops <= 3'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    balance <= 12'd0;
                    op_counter <= 3'd0;
                    max_ops <= valid_ops;
                    
                    if (start) begin
                        if (valid_ops == 3'd0) begin
                            next_state <= DONE_STATE;
                        end else begin
                            next_state <= PROCESSING;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESSING: begin
                    // Apply current operation
                    balance <= balance + operations[op_counter];
                    
                    // Check if balance < 0
                    if (balance < 12'd0) begin
                        result <= 1'b1;
                    end
                    
                    // Increment counter
                    op_counter <= op_counter + 3'd1;
                    
                    // Check if done
                    if (op_counter == max_ops) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= PROCESSING;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule