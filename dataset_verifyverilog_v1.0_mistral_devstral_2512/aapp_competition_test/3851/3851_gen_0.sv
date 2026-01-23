module golden_circle(
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

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_L = 3'd1;
    localparam [2:0] COMPUTE_GCD = 3'd2;
    localparam [2:0] COMPUTE_STOPS = 3'd3;
    localparam [2:0] UPDATE_MIN_MAX = 3'd4;
    localparam [2:0] NEXT_COMBO = 3'd5;
    localparam [2:0] NEXT_I = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    reg [2:0] state, next_state;
    reg [11:0] nk_reg;
    reg [4:0] i_reg;
    reg [1:0] combo_reg;
    reg [11:0] l_reg;
    reg [11:0] min_reg, max_reg;
    reg [11:0] stops_temp;
    reg [11:0] gcd_result_reg;
    reg gcd_start;
    reg gcd_done_flag;
    reg [11:0] gcd_a, gcd_b, gcd_rem;
    reg [1:0] gcd_state;
    localparam [1:0] GCD_IDLE = 2'd0;
    localparam [1:0] GCD_MOD = 2'd1;
    localparam [1:0] GCD_UPDATE = 2'd2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_stops <= 12'd0;
            max_stops <= 12'd0;
            min_reg <= 12'd4095;
            max_reg <= 12'd0;
            i_reg <= 5'd0;
            combo_reg <= 2'd0;
            gcd_start <= 1'b0;
            gcd_done_flag <= 1'b0;
            gcd_state <= GCD_IDLE;
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
                    nk_reg = n * k;
                    i_reg = 5'd0;
                    combo_reg = 2'd0;
                    min_reg = 12'd4095;
                    max_reg = 12'd0;
                    next_state = CALC_L;
                end
            end
            CALC_L: begin
                case (combo_reg)
                    2'd0: l_reg = i_reg * k + b - a;
                    2'd1: l_reg = i_reg * k - b - a;
                    2'd2: l_reg = i_reg * k + b - (k - a);
                    2'd3: l_reg = i_reg * k - b - (k - a);
                    default: l_reg = 12'd0;
                endcase
                if (l_reg >= nk_reg) begin
                    l_reg = l_reg - nk_reg;
                end else if (l_reg < 0) begin
                    l_reg = l_reg + nk_reg;
                end
                next_state = COMPUTE_GCD;
            end
            COMPUTE_GCD: begin
                if (l_reg == 12'd0) begin
                    gcd_result_reg = nk_reg;
                    next_state = COMPUTE_STOPS;
                end else begin
                    if (!gcd_start && !gcd_done_flag) begin
                        gcd_start = 1'b1;
                        gcd_a = nk_reg;
                        gcd_b = l_reg;
                    end else if (gcd_done_flag) begin
                        gcd_start = 1'b0;
                        next_state = COMPUTE_STOPS;
                    end
                end
            end
            COMPUTE_STOPS: begin
                if (gcd_result_reg != 12'd0) begin
                    stops_temp = nk_reg / gcd_result_reg;
                end else begin
                    stops_temp = 12'd0;
                end
                next_state = UPDATE_MIN_MAX;
            end
            UPDATE_MIN_MAX: begin
                if (stops_temp < min_reg) begin
                    min_reg = stops_temp;
                end
                if (stops_temp > max_reg) begin
                    max_reg = stops_temp;
                end
                next_state = NEXT_COMBO;
            end
            NEXT_COMBO: begin
                if (combo_reg < 2'd3) begin
                    combo_reg = combo_reg + 2'd1;
                    next_state = CALC_L;
                end else begin
                    combo_reg = 2'd0;
                    next_state = NEXT_I;
                end
            end
            NEXT_I: begin
                if (i_reg < n - 1) begin
                    i_reg = i_reg + 5'd1;
                    next_state = CALC_L;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                min_stops = min_reg;
                max_stops = max_reg;
                done = 1'b1;
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_state <= GCD_IDLE;
            gcd_done_flag <= 1'b0;
            gcd_result_reg <= 12'd0;
        end else begin
            gcd_done_flag <= 1'b0;
            case (gcd_state)
                GCD_IDLE: begin
                    if (gcd_start) begin
                        if (gcd_b == 12'd0) begin
                            gcd_result_reg <= gcd_a;
                            gcd_done_flag <= 1'b1;
                        end else begin
                            gcd_state <= GCD_MOD;
                        end
                    end
                end
                GCD_MOD: begin
                    gcd_rem <= gcd_a % gcd_b;
                    gcd_state <= GCD_UPDATE;
                end
                GCD_UPDATE: begin
                    gcd_a <= gcd_b;
                    gcd_b <= gcd_rem;
                    if (gcd_rem == 12'd0) begin
                        gcd_result_reg <= gcd_b;
                        gcd_done_flag <= 1'b1;
                        gcd_state <= GCD_IDLE;
                    end else begin
                        gcd_state <= GCD_MOD;
                    end
                end
                default: gcd_state <= GCD_IDLE;
            endcase
        end
    end

endmodule