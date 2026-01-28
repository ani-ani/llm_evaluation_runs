module bracket_checker(
    input clk,
    input rst_n,
    input start,
    input str_valid,
    input [7:0] str_data,
    input str_last,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Stack and pointer
    reg [3:0] stack_ptr;
    reg [15:0] stack;

    // FSM state
    reg [1:0] state;

    // Internal signals
    reg error_flag;
    reg overflow_flag;

    // ASCII values
    localparam [7:0] OPEN_BRACKET = 8'd60;  // '<'
    localparam [7:0] CLOSE_BRACKET = 8'd62; // '>'

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            stack_ptr <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
            error_flag <= 1'b0;
            overflow_flag <= 1'b0;
            // Initialize stack
            stack <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    error_flag <= 1'b0;
                    overflow_flag <= 1'b0;
                    stack_ptr <= 4'd0;
                    stack <= 16'd0;
                    
                    if (start) begin
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    done <= 1'b0;
                    
                    if (str_valid) begin
                        // Process current character
                        if (str_data == OPEN_BRACKET) begin
                            // Push to stack
                            if (stack_ptr < 16) begin
                                stack[stack_ptr] <= 1'b1;
                                stack_ptr <= stack_ptr + 4'd1;
                            end else begin
                                overflow_flag <= 1'b1;
                            end
                        end else if (str_data == CLOSE_BRACKET) begin
                            // Pop from stack
                            if (stack_ptr > 0 && stack[stack_ptr - 4'd1]) begin
                                stack_ptr <= stack_ptr - 4'd1;
                            end else begin
                                error_flag <= 1'b1;
                            end
                        end
                        
                        // Check if this is the last character
                        if (str_last) begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    // Determine result
                    if (overflow_flag || error_flag || stack_ptr != 4'd0) begin
                        result <= 1'b0;
                    end else begin
                        result <= 1'b1;
                    end
                    
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule