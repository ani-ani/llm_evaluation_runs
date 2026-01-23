module snuke_string_counter (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,      // N in [2,16] (4-bit)
    input c_AA,         // 0=A, 1=B
    input c_AB,
    input c_BA,
    input c_BB,
    output reg [29:0] result,
    output reg done
);

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] DECODE = 3'd1;
    localparam [2:0] COMPUTE_POWER = 3'd2;
    localparam [2:0] COMPUTE_FIB = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] N_reg;    // Store N
    reg [3:0] rule;     // {c_AA, c_AB, c_BA, c_BB}
    reg [1:0] rule_type; // 00: type1, 01: type2, 10: type3

    // Power computation registers
    reg [29:0] base;
    reg [3:0] count_power; // counts from 0 to N-3
    wire [3:0] max_power = N_reg - 3;
    localparam [29:0] MOD = 30'd1000000007;

    // Fibonacci computation registers
    reg [29:0] a, b, c;
    reg [3:0] count_fib;   // counts from 4 to N

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = DECODE;
                else
                    next_state = IDLE;
            end
            
            DECODE: begin
                // Determine rule type
                case (rule)
                    // Type 1: Always 1
                    4'b0000, 4'b0001, 4'b0010, 4'b0011,
                    4'b0101, 4'b0111, 4'b1101, 4'b1111:
                        rule_type = 2'b00;
                    // Type 2: 2^(N-3)
                    4'b0100, 4'b1010, 4'b1011, 4'b1100:
                        rule_type = 2'b01;
                    // Type 3: Fibonacci
                    4'b0110, 4'b1000, 4'b1001, 4'b1110:
                        rule_type = 2'b10;
                    default:
                        rule_type = 2'b00;
                endcase

                // Trivial cases
                if (rule_type == 2'b00) begin
                    next_state = DONE_STATE;
                end else if (rule_type == 2'b01) begin
                    if (N_reg <= 3'd3)
                        next_state = DONE_STATE;
                    else
                        next_state = COMPUTE_POWER;
                end else begin
                    if (N_reg <= 3'd3)
                        next_state = DONE_STATE;
                    else
                        next_state = COMPUTE_FIB;
                end
            end
            
            COMPUTE_POWER: begin
                if (count_power < max_power)
                    next_state = COMPUTE_POWER;
                else
                    next_state = DONE_STATE;
            end
            
            COMPUTE_FIB: begin
                if (count_fib <= N_reg)
                    next_state = COMPUTE_FIB;
                else
                    next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                if (!start)
                    next_state = IDLE;
                else
                    next_state = DONE_STATE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 30'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            N_reg <= 4'd0;
            rule <= 4'd0;
            rule_type <= 2'd0;
            base <= 30'd0;
            count_power <= 4'd0;
            a <= 30'd0;
            b <= 30'd0;
            c <= 30'd0;
            count_fib <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        N_reg <= N;
                        rule <= {c_AA, c_AB, c_BA, c_BB};
                    end
                end
                
                DECODE: begin
                    // Trivial cases
                    if (rule_type == 2'b00) begin
                        result <= 30'd1;
                    end else if (rule_type == 2'b01) begin
                        if (N_reg <= 3'd3)
                            result <= 30'd1;
                        else begin
                            base <= 30'd1;
                            count_power <= 4'd0;
                        end
                    end else begin
                        if (N_reg <= 3'd3)
                            result <= 30'd1;
                        else begin
                            a <= 30'd1;
                            b <= 30'd1;
                            count_fib <= 4'd4;
                        end
                    end
                end
                
                COMPUTE_POWER: begin
                    if (count_power < max_power) begin
                        // Multiply by 2 modulo MOD
                        base <= (base << 1) % MOD;
                        count_power <= count_power + 1;
                    end else begin
                        result <= base;
                    end
                end
                
                COMPUTE_FIB: begin
                    if (count_fib <= N_reg) begin
                        c <= (a + b) % MOD;
                        a <= b;
                        b <= c;
                        count_fib <= count_fib + 1;
                    end else begin
                        result <= b;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    result <= 30'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule