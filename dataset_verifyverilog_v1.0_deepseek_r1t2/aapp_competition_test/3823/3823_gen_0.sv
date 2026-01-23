module jeff_rounding(
    input clk,
    input rst_n,
    input start,
    input data_valid,
    input [31:0] data_in,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] GET_N       = 3'd1;
    localparam [2:0] GET_DATA    = 3'd2;
    localparam [2:0] COMPUTE_LR  = 3'd3;
    localparam [2:0] ITERATE_X   = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    // Data storage and counters
    reg [31:0] n_reg;
    reg [31:0] m_reg;
    reg [31:0] T_sum_reg;
    reg [31:0] data_counter_reg;
    reg [31:0] L_reg;
    reg [31:0] R_reg;
    reg [31:0] x_reg;

    // Computation signals
    reg [31:0] min_diff_reg;
    wire [31:0] abs_data_in;
    wire [31:0] fraction_part;

    // Absolute value calculation
    assign abs_data_in = data_in[31] ? (~data_in + 1) : data_in;
    assign fraction_part = abs_data_in % 32'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            n_reg <= 32'd0;
            m_reg <= 32'd0;
            T_sum_reg <= 32'd0;
            data_counter_reg <= 32'd0;
            L_reg <= 32'd0;
            R_reg <= 32'd0;
            x_reg <= 32'd0;
            min_diff_reg <= 32'hFFFFFFFF;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    min_diff_reg <= 32'hFFFFFFFF;
                    if (start) begin
                        state <= GET_N;
                        data_counter_reg <= 32'd0;
                        m_reg <= 32'd0;
                        T_sum_reg <= 32'd0;
                    end
                end

                GET_N: begin
                    if (data_valid) begin
                        n_reg <= data_in;
                        state <= GET_DATA;
                        data_counter_reg <= 32'd0;
                    end
                end

                GET_DATA: begin
                    if (data_valid) begin
                        if (fraction_part != 32'd0) begin
                            m_reg <= m_reg + 32'd1;
                        end
                        T_sum_reg <= T_sum_reg + fraction_part;
                        data_counter_reg <= data_counter_reg + 32'd1;
                        if (data_counter_reg == (2 * n_reg) - 1) begin
                            state <= COMPUTE_LR;
                        end
                    end
                end

                COMPUTE_LR: begin
                    L_reg <= (m_reg > n_reg) ? (m_reg - n_reg) : 32'd0;
                    R_reg <= (m_reg < n_reg) ? m_reg : n_reg;
                    x_reg <= (m_reg > n_reg) ? (m_reg - n_reg) : 32'd0;
                    state <= ITERATE_X;
                    min_diff_reg <= 32'hFFFFFFFF;
                end

                ITERATE_X: begin
                    begin: compute_diff
                        reg signed [63:0] current_diff;
                        reg [31:0] abs_diff;
                        current_diff = (x_reg * 32'd1000) - T_sum_reg;
                        abs_diff = current_diff[31] ? (-current_diff[31:0]) : current_diff[31:0];

                        if (abs_diff < min_diff_reg) begin
                            min_diff_reg <= abs_diff;
                            result <= abs_diff;
                        end

                        if (x_reg < R_reg) begin
                            x_reg <= x_reg + 32'd1;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule