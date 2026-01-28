module barney_probability (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    output reg [31:0] p_out,
    output reg [31:0] q_out,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] INV2 = 32'd500000004;
    localparam [31:0] INV3 = 32'd333333336;

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] EXP_LOOP   = 3'd1;
    localparam [2:0] COMPUTE    = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] n_reg;
    reg [7:0] exp_counter;
    reg [7:0] bit_counter;
    reg [31:0] b;          // 2^n mod MOD
    reg [31:0] b_temp;     // Intermediate for exponentiation
    reg [31:0] q_reg;
    reg [31:0] p_reg;
    reg even_flag;
    reg done_reg;

    // Wires for computations
    wire [63:0] mult_temp1;
    wire [63:0] mult_temp2;
    wire [63:0] mult_temp3;
    wire [31:0] mult_result1;
    wire [31:0] mult_result2;
    wire [31:0] mult_result3;

    // Multiplier logic (modulo multiplication)
    assign mult_temp1 = b_temp * b_temp;
    assign mult_result1 = mult_temp1 % MOD;

    assign mult_temp2 = b * INV2;
    assign mult_result2 = mult_temp2 % MOD;

    wire [31:0] flag_value;
    assign flag_value = even_flag ? 32'd1 : (MOD - 32'd1);

    assign mult_temp3 = mult_result2 * flag_value;
    assign mult_result3 = mult_temp3 % MOD;

    assign mult_temp3 = mult_result3 * INV3;
    wire [31:0] mult_temp4;
    wire [31:0] mult_result4;
    assign mult_temp4 = mult_result3 * INV3;
    assign mult_result4 = mult_temp4 % MOD;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 8'd0;
            exp_counter <= 8'd0;
            bit_counter <= 8'd0;
            b <= 32'd1;
            b_temp <= 32'd1;
            q_reg <= 32'd0;
            p_reg <= 32'd0;
            even_flag <= 1'b0;
            done_reg <= 1'b0;
            p_out <= 32'd0;
            q_out <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    done_reg <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        exp_counter <= 8'd0;
                        bit_counter <= n_in;
                        b <= 32'd1;
                        b_temp <= 32'd1;
                        even_flag <= ~n_in[0];
                        state <= EXP_LOOP;
                    end
                end

                EXP_LOOP: begin
                    if (bit_counter > 8'd0) begin
                        b_temp <= b;
                        if (bit_counter[0]) begin
                            b <= (b * b_temp) % MOD;
                        end else begin
                            b <= b;
                        end
                        bit_counter <= bit_counter - 8'd1;
                        b_temp <= (b_temp * b_temp) % MOD;
                    end else begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // q = b * INV2 % MOD
                    q_reg <= mult_result2;
                    // p = (q + flag) * INV3 % MOD
                    p_reg <= mult_result4;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    p_out <= p_reg;
                    q_out <= q_reg;
                    done <= 1'b1;
                    done_reg <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule