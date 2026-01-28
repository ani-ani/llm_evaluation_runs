module bracket_eval(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] token_type,
    input wire [31:0] token_val,
    input wire token_valid,
    input wire token_end,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [3:0] MAX_STACK_DEPTH = 4'd16;

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal signals
    reg [1:0] state, next_state;
    reg [63:0] accumulator;
    reg [0:0] current_op; // 0: add, 1: mul
    reg [0:0] stack [0:15];
    reg [3:0] stack_ptr;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd1000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            accumulator <= 64'd0;
            current_op <= 1'b0;
            done <= 1'b0;
            ready <= 1'b1;
            cycle_count <= 4'd0;
            stack_ptr <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    cycle_count <= 4'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        ready <= 1'b0;
                        accumulator <= 64'd0;
                        current_op <= 1'b0;
                        stack_ptr <= 4'd0;
                    end
                end
                
                PROCESS: begin
                    ready <= 1'b0;
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (token_valid) begin
                        case (token_type)
                            2'd0: begin // Integer
                                if (current_op == 1'b0) begin
                                    accumulator <= (accumulator + token_val) % MOD;
                                end else begin
                                    accumulator <= (accumulator * token_val) % MOD;
                                end
                            end
                            
                            2'd1: begin // '('
                                if (stack_ptr < MAX_STACK_DEPTH) begin
                                    stack[stack_ptr] <= current_op;
                                    stack_ptr <= stack_ptr + 4'd1;
                                    current_op <= 1'b1;
                                end
                            end
                            
                            2'd2: begin // ')'
                                if (stack_ptr > 4'd0) begin
                                    stack_ptr <= stack_ptr - 4'd1;
                                    current_op <= stack[stack_ptr];
                                end
                            end
                        endcase
                        
                        if (token_end) begin
                            next_state <= FINISH;
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= accumulator[31:0];
                    done <= 1'b1;
                    ready <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule