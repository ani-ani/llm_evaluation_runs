module MinimumBitcoinSpendingToWin(
    input clk,
    input rst_n,
    input start,
    input [7:0] hy,
    input [7:0] ay,
    input [7:0] dy,
    input [7:0] hm,
    input [7:0] am,
    input [7:0] dm,
    input [7:0] h,
    input [7:0] a,
    input [7:0] d,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT     = 3'd1;
    localparam [2:0] LOOP_A   = 3'd2;
    localparam [2:0] LOOP_D   = 3'd3;
    localparam [2:0] CALCULATE = 3'd4;
    localparam [2:0] UPDATE   = 3'd5;
    localparam [2:0] FINISH   = 3'd6;

    reg [2:0] state, next_state;

    // Counters and registers
    reg [7:0] buy_a_reg;
    reg [7:0] buy_d_reg;
    reg [15:0] min_cost;
    reg [15:0] temp_cost;

    // Intermediate calculation registers
    reg [7:0] eff_ay;
    reg [7:0] eff_dy;
    reg [7:0] damage_m;
    reg [7:0] damage_y;
    reg [7:0] turns;
    reg [15:0] hp_loss;
    reg [7:0] hp_needed;

    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            buy_a_reg <= 8'd0;
            buy_d_reg <= 8'd0;
            min_cost <= 16'd65535;
            temp_cost <= 16'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    buy_a_reg <= 8'd0;
                    buy_d_reg <= 8'd0;
                    min_cost <= 16'd65535;
                    next_state <= LOOP_A;
                end

                LOOP_A: begin
                    if (buy_a_reg < 8'd100) begin
                        next_state <= LOOP_D;
                    end else begin
                        next_state <= FINISH;
                    end
                end

                LOOP_D: begin
                    if (buy_d_reg < 8'd100) begin
                        next_state <= CALCULATE;
                    end else begin
                        buy_a_reg <= buy_a_reg + 8'd1;
                        buy_d_reg <= 8'd0;
                        next_state <= LOOP_A;
                    end
                end

                CALCULATE: begin
                    // Calculate effective attributes
                    eff_ay <= ay + buy_a_reg;
                    eff_dy <= dy + buy_d_reg;

                    // Calculate damage values
                    damage_m <= (eff_ay > dm) ? (eff_ay - dm) : 8'd0;
                    damage_y <= (am > eff_dy) ? (am - eff_dy) : 8'd0;

                    // Check if can kill monster
                    if (damage_m == 8'd0) begin
                        next_state <= UPDATE;
                    end else begin
                        // Calculate turns (ceiling division)
                        turns <= (hm + damage_m - 8'd1) / damage_m;

                        // Calculate HP loss and needed
                        hp_loss <= turns * damage_y;
                        hp_needed <= (hp_loss > hy) ? (hp_loss - hy + 8'd1) : 8'd0;

                        // Calculate total cost
                        temp_cost <= (buy_a_reg * a) + (buy_d_reg * d) + (hp_needed * h);

                        next_state <= UPDATE;
                    end
                end

                UPDATE: begin
                    // Update minimum cost if current is valid and better
                    if (damage_m != 8'd0 && temp_cost < min_cost) begin
                        min_cost <= temp_cost;
                    end

                    buy_d_reg <= buy_d_reg + 8'd1;
                    next_state <= LOOP_D;
                end

                FINISH: begin
                    result <= min_cost;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety check for maximum cycles
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE) begin
            state <= IDLE;
            done <= 1'b1;
            result <= min_cost;
        end
    end

endmodule