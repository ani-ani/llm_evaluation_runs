module TopModule(
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

    // State definitions
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] INIT      = 4'd1;
    localparam [3:0] LOOP_A    = 4'd2;
    localparam [3:0] LOOP_D    = 4'd3;
    localparam [3:0] CALCULATE = 4'd4;
    localparam [3:0] UPDATE    = 4'd5;
    localparam [3:0] FINISH    = 4'd6;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] buy_a_reg, buy_d_reg;
    reg [15:0] min_cost, temp_cost;
    
    // Intermediate calculation registers
    reg [7:0] eff_ay, eff_dy;
    reg [7:0] damage_m, damage_y;
    reg [7:0] turns;
    reg [15:0] hp_loss;
    reg [7:0] hp_needed;
    
    // Temporary calculation registers for multi-stage ops
    reg [15:0] calc_temp;
    reg [15:0] calc_result;
    reg [7:0] division_temp;
    
    // Counter for cycles (prevents infinite loops)
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // Stage counter for multi-cycle calculations
    reg [2:0] calc_stage;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            buy_a_reg <= 8'd0;
            buy_d_reg <= 8'd0;
            min_cost <= 16'd65535;
            temp_cost <= 16'd0;
            eff_ay <= 8'd0;
            eff_dy <= 8'd0;
            damage_m <= 8'd0;
            damage_y <= 8'd0;
            turns <= 8'd0;
            hp_loss <= 16'd0;
            hp_needed <= 8'd0;
            calc_temp <= 16'd0;
            calc_result <= 16'd0;
            division_temp <= 8'd0;
            cycle_count <= 8'd0;
            calc_stage <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    buy_a_reg <= 8'd0;
                    buy_d_reg <= 8'd0;
                    min_cost <= 16'd65535;
                    cycle_count <= 8'd0;
                    state <= LOOP_A;
                end
                
                LOOP_A: begin
                    if (buy_a_reg > 8'd100) begin
                        state <= FINISH;
                    end else begin
                        buy_d_reg <= 8'd0;
                        state <= LOOP_D;
                    end
                end
                
                LOOP_D: begin
                    if (buy_d_reg > 8'd100) begin
                        buy_a_reg <= buy_a_reg + 8'd1;
                        state <= LOOP_A;
                    end else begin
                        // Calculate eff_ay = ay + buy_a
                        eff_ay <= ay + buy_a_reg;
                        // Calculate eff_dy = dy + buy_d
                        eff_dy <= dy + buy_d_reg;
                        calc_stage <= 3'd0;
                        state <= CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    case (calc_stage)
                        3'd0: begin
                            // Calculate damage_m = max(0, eff_ay - dm)
                            if (eff_ay > dm) begin
                                damage_m <= eff_ay - dm;
                            end else begin
                                damage_m <= 8'd0;
                            end
                            calc_stage <= 3'd1;
                        end
                        
                        3'd1: begin
                            // Skip if damage_m == 0
                            if (damage_m == 8'd0) begin
                                buy_d_reg <= buy_d_reg + 8'd1;
                                state <= LOOP_D;
                            end else begin
                                // Calculate damage_y = max(0, am - eff_dy)
                                if (am > eff_dy) begin
                                    damage_y <= am - eff_dy;
                                end else begin
                                    damage_y <= 8'd0;
                                end
                                calc_stage <= 3'd2;
                            end
                        end
                        
                        3'd2: begin
                            // Calculate turns = ceil(hm / damage_m)
                            // turns = (hm + damage_m - 1) / damage_m
                            if (hm == 8'd0) begin
                                turns <= 8'd1;
                            end else begin
                                division_temp <= (hm + damage_m - 8'd1) / damage_m;
                            end
                            calc_stage <= 3'd3;
                        end
                        
                        3'd3: begin
                            // Store turns
                            if (hm == 8'd0) begin
                                turns <= 8'd1;
                            end else begin
                                turns <= division_temp;
                            end
                            calc_stage <= 3'd4;
                        end
                        
                        3'd4: begin
                            // Calculate hp_loss = turns * damage_y
                            hp_loss <= turns * damage_y;
                            calc_stage <= 3'd5;
                        end
                        
                        3'd5: begin
                            // Calculate hp_needed = max(0, hp_loss - hy + 1)
                            if (hp_loss > hy) begin
                                hp_needed <= hp_loss - hy + 16'd1;
                            end else begin
                                hp_needed <= 8'd0;
                            end
                            calc_stage <= 3'd6;
                        end
                        
                        3'd6: begin
                            // Calculate cost = buy_a * a + buy_d * d + hp_needed * h
                            temp_cost <= (buy_a_reg * a) + (buy_d_reg * d) + (hp_needed * h);
                            calc_stage <= 3'd7;
                        end
                        
                        3'd7: begin
                            state <= UPDATE;
                        end
                    endcase
                end
                
                UPDATE: begin
                    // Update min_cost if current cost is smaller
                    if (temp_cost < min_cost) begin
                        min_cost <= temp_cost;
                    end
                    buy_d_reg <= buy_d_reg + 8'd1;
                    state <= LOOP_D;
                end
                
                FINISH: begin
                    result <= min_cost;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Increment cycle count for safety
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= FINISH;
                end
            end
        end
    end

endmodule