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

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] EXP_LOOP = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] n_reg;
    reg parity;
    reg [31:0] b_reg;
    reg [31:0] q_reg;
    reg [31:0] flag_reg;
    reg [31:0] p_reg;
    reg [4:0] exp_count;
    reg [31:0] base_reg;
    reg [31:0] result_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            n_reg <= 8'd0;
            parity <= 1'b0;
            b_reg <= 32'd0;
            q_reg <= 32'd0;
            flag_reg <= 32'd0;
            p_reg <= 32'd0;
            exp_count <= 5'd0;
            base_reg <= 32'd0;
            result_reg <= 32'd0;
            p_out <= 32'd0;
            q_out <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    n_reg = n_in;
                    parity = n_in[0];
                    base_reg = 32'd2;
                    result_reg = 32'd1;
                    exp_count = n_in;
                    next_state = EXP_LOOP;
                end
            end

            EXP_LOOP: begin
                if (exp_count > 0) begin
                    if (exp_count[0]) begin
                        result_reg = (result_reg * base_reg) % MOD;
                    end
                    base_reg = (base_reg * base_reg) % MOD;
                    exp_count = exp_count >> 1;
                end else begin
                    b_reg = result_reg;
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                q_reg = (b_reg * INV2) % MOD;
                flag_reg = parity ? (MOD - 1) : 1;
                p_reg = ((q_reg + flag_reg) * INV3) % MOD;
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                done = 1'b1;
                p_out = p_reg;
                q_out = q_reg;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule