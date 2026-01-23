module golden_circle (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [8:0] k,
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [11:0] min_stops,
    output reg [11:0] max_stops,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] CALC_L       = 4'd1;
    localparam [3:0] GCD_START    = 4'd2;
    localparam [3:0] GCD_LOOP     = 4'd3;
    localparam [3:0] GCD_DONE     = 4'd4;
    localparam [3:0] COMPUTE_STOPS= 4'd5;
    localparam [3:0] UPDATE_MIN   = 4'd6;
    localparam [3:0] UPDATE_MAX   = 4'd7;
    localparam [3:0] NEXT_COMBO   = 4'd8;
    localparam [3:0] NEXT_I       = 4'd9;
    localparam [3:0] FINISH       = 4'd10;

    // Internal registers
    reg [3:0] state;
    reg [11:0] nk_reg;
    reg [11:0] i_reg;
    reg [1:0] combo_reg;
    reg [11:0] l_reg;
    reg [11:0] min_reg;
    reg [11:0] max_reg;
    reg [11:0] stops_temp;
    reg [11:0] gcd_a;
    reg [11:0] gcd_b;
    reg [11:0] gcd_rem;
    reg [11:0] gcd_result;
    reg gcd_valid;

    // Temporary variables for L calculation
    reg signed [12:0] l_temp_signed;
    wire [11:0] i_k = i_reg * k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_stops <= 12'd0;
            max_stops <= 12'd0;
            nk_reg <= 12'd0;
            i_reg <= 12'd0;
            combo_reg <= 2'd0;
            l_reg <= 12'd0;
            min_reg <= 12'hFFF;
            max_reg <= 12'd0;
            stops_temp <= 12'd0;
            gcd_a <= 12'd0;
            gcd_b <= 12'd0;
            gcd_rem <= 12'd0;
            gcd_result <= 12'd0;
            gcd_valid <= 1'b0;
            l_temp_signed <= 13'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        nk_reg <= n * k;
                        i_reg <= 12'd0;
                        combo_reg <= 2'd0;
                        min_reg <= 12'hFFF;
                        max_reg <= 12'd0;
                        state <= CALC_L;
                    end
                end

                CALC_L: begin
                    case (combo_reg)
                        2'd0: l_temp_signed = i_k + b - a;
                        2'd1: l_temp_signed = i_k - b - a;
                        2'd2: l_temp_signed = i_k + b - (k - a);
                        2'd3: l_temp_signed = i_k - b - (k - a);
                        default: l_temp_signed = 13'sd0;
                    endcase
                    state <= GCD_START;
                end

                GCD_START: begin
                    // Adjust l to [0, nk-1]
                    if (l_temp_signed >= nk_reg) begin
                        l_reg <= l_temp_signed - nk_reg;
                    end else if (l_temp_signed < 0) begin
                        l_reg <= l_temp_signed + nk_reg;
                    end else begin
                        l_reg <= l_temp_signed[11:0];
                    end
                    state <= GCD_LOOP;
                end

                GCD_LOOP: begin
                    if (l_reg == 0) begin
                        gcd_result <= nk_reg;
                        state <= GCD_DONE;
                    end else begin
                        gcd_a <= nk_reg;
                        gcd_b <= l_reg;
                        state <= GCD_DONE;
                    end
                end

                GCD_DONE: begin
                    // Compute GCD
                    if (gcd_b == 0) begin
                        gcd_result <= gcd_a;
                    end else begin
                        gcd_rem <= gcd_a % gcd_b;
                    end
                    if (gcd_b != 0) begin
                        gcd_a <= gcd_b;
                        gcd_b <= gcd_rem;
                    end
                    state <= COMPUTE_STOPS;
                end

                COMPUTE_STOPS: begin
                    if (gcd_result != 0) begin
                        stops_temp <= nk_reg / gcd_result;
                    end else begin
                        stops_temp <= 12'd0;
                    end
                    state <= UPDATE_MIN;
                end

                UPDATE_MIN: begin
                    if (stops_temp < min_reg) begin
                        min_reg <= stops_temp;
                    end
                    state <= UPDATE_MAX;
                end

                UPDATE_MAX: begin
                    if (stops_temp > max_reg) begin
                        max_reg <= stops_temp;
                    end
                    state <= NEXT_COMBO;
                end

                NEXT_COMBO: begin
                    if (combo_reg < 2'd3) begin
                        combo_reg <= combo_reg + 1;
                        state <= CALC_L;
                    end else begin
                        combo_reg <= 2'd0;
                        state <= NEXT_I;
                    end
                end

                NEXT_I: begin
                    if (i_reg < (n - 1)) begin
                        i_reg <= i_reg + 1;
                        state <= CALC_L;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    min_stops <= min_reg;
                    max_stops <= max_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule