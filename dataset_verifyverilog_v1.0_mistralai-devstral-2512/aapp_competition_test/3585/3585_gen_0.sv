module max_bags_finder(
    input clk,
    input rst_n,
    input start,
    input [31:0] m_in,
    input [31:0] k_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd998244353;
    localparam [31:0] MAX_CYCLES = 32'd1000;

    // States
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_BASE = 2'd1;
    localparam [1:0] COMPUTE_EXP = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [31:0] base;
    reg [31:0] exponent;
    reg [31:0] current_result;
    reg [31:0] current_base;
    reg [31:0] cycle_count;
    reg [31:0] bit_index;

    // Compute base = (2*m + 1) % MOD
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 32'd0;
            bit_index <= 32'd0;
            current_result <= 32'd1;
            current_base <= 32'd0;
            base <= 32'd0;
            exponent <= 32'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_BASE;
                end else begin
                    next_state = IDLE;
                end
            end

            COMPUTE_BASE: begin
                next_state = COMPUTE_EXP;
            end

            COMPUTE_EXP: begin
                if (bit_index >= 32 || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPUTE_EXP;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                end

                COMPUTE_BASE: begin
                    // Compute base = (2*m_in + 1) % MOD
                    base <= (2 * m_in + 1) % MOD;
                    exponent <= k_in;
                    current_result <= 32'd1;
                    current_base <= base;
                    bit_index <= 32'd0;
                    cycle_count <= 32'd0;
                end

                COMPUTE_EXP: begin
                    cycle_count <= cycle_count + 32'd1;
                    
                    // Binary exponentiation
                    if (bit_index < 32) begin
                        // Check current bit of exponent
                        if (exponent[bit_index]) begin
                            // Multiply result by current_base mod MOD
                            current_result <= (current_result * current_base) % MOD;
                        end
                        
                        // Square current_base mod MOD
                        current_base <= (current_base * current_base) % MOD;
                        bit_index <= bit_index + 32'd1;
                    end
                end

                DONE_STATE: begin
                    result <= current_result;
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                    result <= 32'd0;
                end
            endcase
        end
    end

endmodule