module barney_probability(
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    output reg [31:0] p_out,
    output reg [31:0] q_out,
    output reg done
);

    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] INV2 = 32'd500000004;
    localparam [31:0] INV3 = 32'd333333336;

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] EXP_LOOP  = 2'd1;
    localparam [1:0] COMPUTE   = 2'd2;
    localparam [1:0] DONE_STATE= 2'd3;

    reg [1:0] state;
    reg [7:0] captured_n;
    reg parity;
    reg [31:0] b_reg;
    reg [31:0] base_reg;
    reg [31:0] exp_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            captured_n <= 8'd0;
            parity <= 1'b0;
            b_reg <= 32'd0;
            base_reg <= 32'd0;
            exp_reg <= 32'd0;
            p_out <= 32'd0;
            q_out <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        captured_n <= n_in;
                        parity <= n_in[0];
                        b_reg <= 32'd1;
                        base_reg <= 32'd2;
                        exp_reg <= {24'd0, n_in};
                        state <= EXP_LOOP;
                    end else begin
                        state <= IDLE;
                    end
                end

                EXP_LOOP: begin
                    if (exp_reg != 32'd0) begin
                        if (exp_reg[0]) begin
                            b_reg <= (b_reg * base_reg) % MOD;
                        end
                        base_reg <= (base_reg * base_reg) % MOD;
                        exp_reg <= exp_reg >> 1;
                    end else begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    q_out <= (b_reg * INV2) % MOD;
                    if (parity) begin
                        p_out <= ( ( ( (b_reg * INV2) % MOD + (MOD - 32'd1) ) % MOD ) * INV3 ) % MOD;
                    end else begin
                        p_out <= ( ( ( (b_reg * INV2) % MOD + 32'd1 ) % MOD ) * INV3 ) % MOD;
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule