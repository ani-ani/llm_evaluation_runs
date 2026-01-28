module max_chessmen(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    input wire [15:0] m,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] SWAP_NM       = 4'd1;
    localparam [3:0] CHECK_N1      = 4'd2;
    localparam [3:0] COMPUTE_N1    = 4'd3;
    localparam [3:0] CHECK_N2      = 4'd4;
    localparam [3:0] CHECK_SPECIAL = 4'd5;
    localparam [3:0] COMPUTE_GEN   = 4'd6;
    localparam [3:0] DONE_STATE    = 4'd7;

    reg [3:0] state, next_state;
    reg [15:0] n_reg, m_reg;
    reg [15:0] temp_n, temp_m;
    reg [15:0] m_mod6;
    reg [15:0] m_div6;
    reg [15:0] add_val;
    reg [15:0] counter;
    reg [15:0] i;
    reg [31:0] product;
    reg n_eq_1, n_eq_2, m_eq_2, m_eq_3, m_eq_7;
    reg n_ge_3;
    reg m_is_even, n_is_even;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            n_reg <= 16'd0;
            m_reg <= 16'd0;
            temp_n <= 16'd0;
            temp_m <= 16'd0;
            m_mod6 <= 16'd0;
            m_div6 <= 16'd0;
            add_val <= 16'd0;
            counter <= 16'd0;
            i <= 16'd0;
            product <= 32'd0;
            n_eq_1 <= 1'b0;
            n_eq_2 <= 1'b0;
            m_eq_2 <= 1'b0;
            m_eq_3 <= 1'b0;
            m_eq_7 <= 1'b0;
            n_ge_3 <= 1'b0;
            m_is_even <= 1'b0;
            n_is_even <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SWAP_NM;
                end
            end
            SWAP_NM: begin
                next_state = CHECK_N1;
            end
            CHECK_N1: begin
                if (n_eq_1) begin
                    next_state = COMPUTE_N1;
                end else begin
                    next_state = CHECK_N2;
                end
            end
            COMPUTE_N1: begin
                next_state = DONE_STATE;
            end
            CHECK_N2: begin
                if (n_eq_2) begin
                    next_state = CHECK_SPECIAL;
                end else begin
                    next_state = COMPUTE_GEN;
                end
            end
            CHECK_SPECIAL: begin
                next_state = DONE_STATE;
            end
            COMPUTE_GEN: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Register updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n_reg <= 16'd0;
            m_reg <= 16'd0;
            temp_n <= 16'd0;
            temp_m <= 16'd0;
            m_mod6 <= 16'd0;
            m_div6 <= 16'd0;
            add_val <= 16'd0;
            counter <= 16'd0;
            i <= 16'd0;
            product <= 32'd0;
        end else begin
            case (state)
                SWAP_NM: begin
                    temp_n <= n;
                    temp_m <= m;
                    if (n > m) begin
                        n_reg <= m;
                        m_reg <= n;
                    end else begin
                        n_reg <= n;
                        m_reg <= m;
                    end
                end
                COMPUTE_N1: begin
                    if (counter < 6) begin
                        if (m_reg >= 6) begin
                            m_div6 <= m_div6 + 16'd1;
                            m_mod6 <= m_reg - 6;
                        end else begin
                            m_mod6 <= m_reg;
                        end
                        counter <= counter + 16'd1;
                    end else begin
                        add_val <= (m_mod6 > 3) ? (m_mod6 - 3) : 0;
                        result <= (m_div6 * 6) + (add_val * 2);
                    end
                end
                CHECK_SPECIAL: begin
                    if (m_eq_2) begin
                        result <= 32'd0;
                    end else if (m_eq_3) begin
                        result <= 32'd4;
                    end else if (m_eq_7) begin
                        result <= 32'd12;
                    end else begin
                        product <= n_reg * m_reg;
                        result <= product;
                    end
                end
                COMPUTE_GEN: begin
                    if (n_ge_3) begin
                        if (m_is_even && n_is_even) begin
                            result <= n_reg * m_reg;
                        end else begin
                            result <= (n_reg * m_reg) - 1;
                        end
                    end
                end
            endcase
        end
    end

    // Comparator logic
    always @(*) begin
        n_eq_1 = (n_reg == 16'd1);
        n_eq_2 = (n_reg == 16'd2);
        m_eq_2 = (m_reg == 16'd2);
        m_eq_3 = (m_reg == 16'd3);
        m_eq_7 = (m_reg == 16'd7);
        n_ge_3 = (n_reg >= 16'd3);
        m_is_even = (m_reg[0] == 1'b0);
        n_is_even = (n_reg[0] == 1'b0);
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            case (state)
                DONE_STATE: done <= 1'b1;
                default: done <= 1'b0;
            endcase
        end
    end

endmodule