module max_chessmen (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    input wire [15:0] m,
    output reg [31:0] result,
    output reg done
);

    // State machine states
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK_N1 = 4'd1;
    localparam [3:0] COMPUTE_N1 = 4'd2;
    localparam [3:0] CHECK_N2 = 4'd3;
    localparam [3:0] CHECK_SPECIAL = 4'd4;
    localparam [3:0] COMPUTE_GENERAL = 4'd5;
    localparam [3:0] DONE = 4'd6;
    localparam [3:0] SWAP_N_M = 4'd7;
    localparam [3:0] MOD_M6 = 4'd8;
    localparam [3:0] MOD_N2 = 4'd9;
    localparam [3:0] MOD_M2 = 4'd10;
    localparam [3:0] MULT_RESULTS = 4'd11;

    reg [3:0] state, next_state;
    reg [15:0] n_reg, m_reg, n_swap, m_swap;
    reg [31:0] result_reg;
    reg [31:0] mul_a, mul_b;
    wire [31:0] mul_result;
    reg mul_start;
    wire mul_done;

    // Modulo variables (subtractive loops)
    reg [15:0] mod_val;
    reg [15:0] mod_sub;
    reg [15:0] mod_count;
    reg mod_done_flag;
    reg mod_clear;

    // Special case flags
    reg n_is_1, n_is_2, m_is_2, m_is_3, m_is_7;
    reg [2:0] mod6_result;
    reg [1:0] mod2_n_result;
    reg [1:0] mod2_m_result;

    // Multiply module (synchronous)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_a <= 32'd0;
            mul_b <= 32'd0;
        end else if (mul_start) begin
            mul_a <= {16'd0, n_swap};
            mul_b <= {16'd0, m_swap};
        end
    end
    assign mul_result = mul_a * mul_b;

    // FSM Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            n_reg <= 16'd0;
            m_reg <= 16'd0;
            n_swap <= 16'd0;
            m_swap <= 16'd0;
            mul_start <= 1'b0;
            mod_val <= 16'd0;
            mod_sub <= 16'd0;
            mod_count <= 16'd0;
            mod_done_flag <= 1'b0;
            mod_clear <= 1'b0;
            n_is_1 <= 1'b0;
            n_is_2 <= 1'b0;
            m_is_2 <= 1'b0;
            m_is_3 <= 1'b0;
            m_is_7 <= 1'b0;
            mod6_result <= 3'd0;
            mod2_n_result <= 2'd0;
            mod2_m_result <= 2'd0;
        end else begin
            state <= next_state;
            done <= (next_state == DONE) ? 1'b1 : 1'b0;

            // Default flags
            if (start) begin
                n_reg <= n;
                m_reg <= m;
                mul_start <= 1'b0;
                mod_clear <= 1'b1;
                n_is_1 <= 1'b0;
                n_is_2 <= 1'b0;
                m_is_2 <= 1'b0;
                m_is_3 <= 1'b0;
                m_is_7 <= 1'b0;
                mod6_result <= 3'd0;
                mod2_n_result <= 2'd0;
                mod2_m_result <= 2'd0;
            end else begin
                mod_clear <= 1'b0;
            end

            // Subtractive loop logic
            if (mod_clear) begin
                mod_val <= 16'd0;
                mod_sub <= 16'd0;
                mod_count <= 16'd0;
                mod_done_flag <= 1'b0;
            end else if (state == MOD_M6 && !mod_done_flag) begin
                if (mod_val < 16'd6) begin
                    mod_done_flag <= 1'b1;
                    mod6_result <= mod_val[2:0];
                end else begin
                    mod_val <= mod_val - 16'd6;
                end
            end else if (state == MOD_N2 && !mod_done_flag) begin
                if (mod_val < 16'd2) begin
                    mod_done_flag <= 1'b1;
                    mod2_n_result <= mod_val[1:0];
                end else begin
                    mod_val <= mod_val - 16'd2;
                end
            end else if (state == MOD_M2 && !mod_done_flag) begin
                if (mod_val < 16'd2) begin
                    mod_done_flag <= 1'b1;
                    mod2_m_result <= mod_val[1:0];
                end else begin
                    mod_val <= mod_val - 16'd2;
                end
            end

            // Flag updates
            if (state == CHECK_N1) begin
                n_is_1 <= (n_reg == 16'd1);
                n_is_2 <= (n_reg == 16'd2);
            end
            if (state == CHECK_SPECIAL) begin
                m_is_2 <= (m_reg == 16'd2);
                m_is_3 <= (m_reg == 16'd3);
                m_is_7 <= (m_reg == 16'd7);
            end

            // Result calculation
            if (state == COMPUTE_N1) begin
                // Compute max(0, m%6 - 3)
                if (mod6_result > 3'd3) begin
                    result_reg <= {16'd0, m_reg} - 16'd3 - {13'd0, mod6_result};
                end else begin
                    result_reg <= 32'd0;
                end
            end else if (state == COMPUTE_GENERAL) begin
                // n*m if even, n*m-1 if odd
                if (mod2_n_result == 2'd0 || mod2_m_result == 2'd0) begin
                    mul_start <= 1'b1;
                end else begin
                    mul_start <= 1'b1;
                end
            end else if (state == MULT_RESULTS) begin
                mul_start <= 1'b0;
                if (mod2_n_result != 2'd0 && mod2_m_result != 2'd0) begin
                    result <= mul_result - 32'd1;
                end else begin
                    result <= mul_result;
                end
            end else if (state == DONE) begin
                // N/A, done is set above
            end
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SWAP_N_M;
                else next_state = IDLE;
            end

            SWAP_N_M: begin
                if (n_reg > m_reg) begin
                    n_swap <= m_reg;
                    m_swap <= n_reg;
                end else begin
                    n_swap <= n_reg;
                    m_swap <= m_reg;
                end
                next_state = CHECK_N1;
            end

            CHECK_N1: begin
                if (n_swap == 16'd1) begin
                    mod_val <= m_swap;
                    next_state = MOD_M6;
                end else begin
                    next_state = CHECK_N2;
                end
            end

            MOD_M6: begin
                if (mod_done_flag) next_state = COMPUTE_N1;
                else next_state = MOD_M6;
            end

            COMPUTE_N1: begin
                result <= (m_swap * 2) - (result_reg * 2);
                next_state = DONE;
            end

            CHECK_N2: begin
                if (n_swap == 16'd2) begin
                    mod_val <= m_swap;
                    next_state = MOD_M2;
                end else begin
                    next_state = MOD_N2;
                end
            end

            MOD_M2: begin
                if (mod_done_flag) next_state = CHECK_SPECIAL;
                else next_state = MOD_M2;
            end

            CHECK_SPECIAL: begin
                if (m_swap == 16'd2) result <= 32'd0;
                else if (m_swap == 16'd3) result <= 32'd4;
                else if (m_swap == 16'd7) result <= 32'd12;
                else result <= {16'd0, n_swap} * {16'd0, m_swap};
                
                if (m_swap == 16'd2 || m_swap == 16'd3 || m_swap == 16'd7)
                    next_state = DONE;
                else
                    next_state = MULT_RESULTS;
            end

            MOD_N2: begin
                if (mod_done_flag) next_state = MOD_M2_CHECK;
                else next_state = MOD_N2;
            end

            MOD_M2_CHECK: begin
                // We need to check M parity again for General case
                mod_val <= m_swap;
                mod_done_flag <= 1'b0;
                next_state = MOD_M2_GENERAL;
            end

            MOD_M2_GENERAL: begin
                if (mod_done_flag) next_state = COMPUTE_GENERAL;
                else next_state = MOD_M2_GENERAL;
            end

            COMPUTE_GENERAL: begin
                next_state = MULT_RESULTS;
            end

            MULT_RESULTS: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule