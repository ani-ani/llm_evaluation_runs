module bracket_eval (
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
    localparam [2:0] OP_ADD = 3'd0;
    localparam [2:0] OP_MUL = 3'd1;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] current_op;
    reg [31:0] accumulator;       // 32-bit modulo result
    reg [63:0] accum_64;         // 64-bit for intermediate multiplication
    reg [3:0] stack_ptr;          // Stack pointer (max 16)
    reg [2:0] stack [0:15];       // Stack stores operations
    reg [2:0] next_op;
    reg [63:0] mult_temp;
    reg [31:0] mod_temp;
    
    // Counter for latency
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // FSM next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PROCESS;
                else next_state = IDLE;
            end
            PROCESS: begin
                if (token_valid || token_end) begin
                    // Process token
                    if (token_end && (token_type == 2'd2 || !token_valid)) begin
                        next_state = FINISH;
                    end else begin
                        next_state = PROCESS;
                    end
                end else begin
                    next_state = PROCESS;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b1;
            done <= 1'b0;
            result <= 32'd0;
            accumulator <= 32'd0;
            accum_64 <= 64'd0;
            current_op <= OP_ADD;
            stack_ptr <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    result <= 32'd0;
                    accumulator <= 32'd0;
                    accum_64 <= 64'd0;
                    current_op <= OP_ADD;
                    stack_ptr <= 4'd0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        ready <= 1'b0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    done <= 1'b0;
                    
                    if (token_valid || token_end) begin
                        if (token_type == 2'd0) begin  // Integer
                            if (current_op == OP_ADD) begin
                                // Accum = (accum + val) % MOD
                                accum_64 <= {32'd0, accumulator} + {32'd0, token_val};
                                mod_temp <= (accumulator + token_val) % MOD;
                                accumulator <= (accumulator + token_val) % MOD;
                            end else begin  // OP_MUL
                                // Accum = (accum * val) % MOD
                                mult_temp <= {32'd0, accumulator} * {32'd0, token_val};
                                // Use 64-bit for multiplication, then mod
                                accumulator <= ({32'd0, accumulator} * {32'd0, token_val}) % MOD;
                            end
                        end else if (token_type == 2'd1) begin  // '('
                            if (stack_ptr < 4'd15) begin
                                stack[stack_ptr] <= current_op;
                                stack_ptr <= stack_ptr + 4'd1;
                                current_op <= OP_MUL;
                            end
                        end else if (token_type == 2'd2) begin  // ')'
                            if (stack_ptr > 4'd0) begin
                                stack_ptr <= stack_ptr - 4'd1;
                                current_op <= stack[stack_ptr - 4'd1];
                            end
                        end
                        
                        // If token_end is high, finish
                        if (token_end) begin
                            // No immediate done here - wait for next cycle
                            // to ensure final computation completes
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= accumulator;
                end
                
                default: begin
                    state <= IDLE;
                    ready <= 1'b1;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
endmodule