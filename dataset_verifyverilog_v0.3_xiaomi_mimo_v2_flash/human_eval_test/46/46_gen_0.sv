module fib4 (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [4:0] n_reg;
    reg [4:0] iteration_counter;
    reg [15:0] f0, f1, f2, f3;
    reg [15:0] next_result;
    
    // Combinational logic for next state
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COMPUTE: begin
                if (n_reg <= 3'd3) begin
                    // Base cases - done immediately
                    next_state = DONE_STATE;
                end else begin
                    // Iterative computation
                    if (iteration_counter >= (n_reg - 3'd3)) begin
                        next_state = DONE_STATE;
                    end else begin
                        next_state = COMPUTE;
                    end
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic for state updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 5'd0;
            iteration_counter <= 5'd0;
            f0 <= 16'd0;
            f1 <= 16'd0;
            f2 <= 16'd0;
            f3 <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        iteration_counter <= 5'd0;
                        // Initialize base values
                        case (n)
                            5'd0: begin
                                f0 <= 16'd0;
                                f1 <= 16'd0;
                                f2 <= 16'd0;
                                f3 <= 16'd0;
                            end
                            5'd1: begin
                                f0 <= 16'd0;
                                f1 <= 16'd0;
                                f2 <= 16'd0;
                                f3 <= 16'd0;
                            end
                            5'd2: begin
                                f0 <= 16'd0;
                                f1 <= 16'd0;
                                f2 <= 16'd2;
                                f3 <= 16'd0;
                            end
                            5'd3: begin
                                f0 <= 16'd0;
                                f1 <= 16'd0;
                                f2 <= 16'd2;
                                f3 <= 16'd0;
                            end
                            default: begin
                                // For n >= 4, initialize with base cases
                                f0 <= 16'd0;  // fib4(0)
                                f1 <= 16'd0;  // fib4(1)
                                f2 <= 16'd2;  // fib4(2)
                                f3 <= 16'd0;  // fib4(3)
                            end
                        endcase
                    end
                end
                
                COMPUTE: begin
                    if (n_reg <= 3'd3) begin
                        // Base cases - output result directly
                        case (n_reg)
                            5'd0: result <= 16'd0;
                            5'd1: result <= 16'd0;
                            5'd2: result <= 16'd2;
                            5'd3: result <= 16'd0;
                            default: result <= 16'd0;
                        endcase
                    end else begin
                        // Iterative computation
                        if (iteration_counter < (n_reg - 3'd3)) begin
                            // Compute next value
                            result <= f3 + f2 + f1 + f0;
                            // Shift values for next iteration
                            f0 <= f1;
                            f1 <= f2;
                            f2 <= f3;
                            f3 <= f3 + f2 + f1 + f0;
                            // Increment counter
                            iteration_counter <= iteration_counter + 5'd1;
                        end else begin
                            // Last iteration complete
                            result <= f3;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    // State is IDLE after reset
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
endmodule