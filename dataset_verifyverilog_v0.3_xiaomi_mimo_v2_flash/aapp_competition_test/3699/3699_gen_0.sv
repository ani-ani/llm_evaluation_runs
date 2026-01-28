module recycling_optimization (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] ax, ay,
    input wire [31:0] bx, by,
    input wire [31:0] tx, ty,
    input wire [2:0] num_bottles,
    input wire [31:0] bottle_x_0, bottle_x_1, bottle_x_2, bottle_x_3,
    input wire [31:0] bottle_x_4, bottle_x_5, bottle_x_6, bottle_x_7,
    input wire [31:0] bottle_y_0, bottle_y_1, bottle_y_2, bottle_y_3,
    input wire [31:0] bottle_y_4, bottle_y_5, bottle_y_6, bottle_y_7,
    output reg [63:0] total_distance,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_DIST = 3'd1;
    localparam [2:0] CALC_SAVINGS = 3'd2;
    localparam [2:0] SELECT_TASKS = 3'd3;
    localparam [2:0] CALC_RESULT = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    
    reg [2:0] state;
    reg [5:0] counter;
    reg [2:0] bottle_idx;
    
    // Internal storage
    reg [63:0] dist_bin [0:7];
    reg [63:0] dist_adil [0:7];
    reg [63:0] dist_bera [0:7];
    reg signed [63:0] savings_adil [0:7];
    reg signed [63:0] savings_bera [0:7];
    reg signed [63:0] best_savings_adil;
    reg signed [63:0] second_best_savings_adil;
    reg signed [63:0] best_savings_bera;
    reg signed [63:0] second_best_savings_bera;
    reg [2:0] best_idx_adil;
    reg [2:0] second_best_idx_adil;
    reg [2:0] best_idx_bera;
    reg [2:0] second_best_idx_bera;
    reg [63:0] base_cost_sum;
    reg signed [63:0] max_savings;
    
    // Fixed-point multiplication
    function automatic [63:0] fp_mult;
        input [31:0] a, b;
        reg [63:0] prod;
        begin
            prod = { {32{a[31]}}, a } * { {32{b[31]}}, b };
            fp_mult = prod >>> 16;
        end
    endfunction
    
    // Fixed-point square root (approximation)
    function automatic [31:0] fp_sqrt;
        input [63:0] n;
        reg [63:0] t, q, b, r;
        integer i;
        begin
            t = 64'h8000000000000000;
            q = 64'h0;
            r = n;
            for (i = 0; i < 32; i = i + 1) begin
                b = q | t;
                q = q >> 1;
                if (r >= b) begin
                    r = r - b;
                    q = q | t;
                end
                t = t >> 2;
            end
            fp_sqrt = q[31:0];
        end
    endfunction
    
    // Distance calculation
    function automatic [63:0] calc_distance;
        input [31:0] x1, y1, x2, y2;
        reg [31:0] dx, dy;
        reg [63:0] dx_sq, dy_sq, sum_sq;
        begin
            if (x1 > x2) dx = x1 - x2; else dx = x2 - x1;
            if (y1 > y2) dy = y1 - y2; else dy = y2 - y1;
            dx_sq = fp_mult(dx, dx);
            dy_sq = fp_mult(dy, dy);
            sum_sq = dx_sq + dy_sq;
            calc_distance = fp_sqrt(sum_sq);
        end
    endfunction
    
    // Combinational logic for savings
    always @(*) begin
        for (integer i = 0; i < 8; i = i + 1) begin
            if (i < num_bottles) begin
                savings_adil[i] = dist_bin[i] - dist_adil[i];
                savings_bera[i] = dist_bin[i] - dist_bera[i];
            end else begin
                savings_adil[i] = 64'sd0;
                savings_bera[i] = 64'sd0;
            end
        end
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 6'd0;
            bottle_idx <= 3'd0;
            total_distance <= 64'd0;
            done <= 1'b0;
            best_savings_adil <= 64'sd0;
            second_best_savings_adil <= 64'sd0;
            best_savings_bera <= 64'sd0;
            second_best_savings_bera <= 64'sd0;
            best_idx_adil <= 3'd0;
            second_best_idx_adil <= 3'd0;
            best_idx_bera <= 3'd0;
            second_best_idx_bera <= 3'd0;
            base_cost_sum <= 64'd0;
            max_savings <= 64'sd0;
            for (integer i = 0; i < 8; i = i + 1) begin
                dist_bin[i] <= 64'd0;
                dist_adil[i] <= 64'd0;
                dist_bera[i] <= 64'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 6'd0;
                    bottle_idx <= 3'd0;
                    if (start) begin
                        state <= CALC_DIST;
                    end
                end
                
                CALC_DIST: begin
                    if (counter < num_bottles) begin
                        case (counter)
                            0: begin
                                dist_bin[0] <= calc_distance(tx, ty, bottle_x_0, bottle_y_0);
                                dist_adil[0] <= calc_distance(ax, ay, bottle_x_0, bottle_y_0);
                                dist_bera[0] <= calc_distance(bx, by, bottle_x_0, bottle_y_0);
                            end
                            1: begin
                                dist_bin[1] <= calc_distance(tx, ty, bottle_x_1, bottle_y_1);
                                dist_adil[1] <= calc_distance(ax, ay, bottle_x_1, bottle_y_1);
                                dist_bera[1] <= calc_distance(bx, by, bottle_x_1, bottle_y_1);
                            end
                            2: begin
                                dist_bin[2] <= calc_distance(tx, ty, bottle_x_2, bottle_y_2);
                                dist_adil[2] <= calc_distance(ax, ay, bottle_x_2, bottle_y_2);
                                dist_bera[2] <= calc_distance(bx, by, bottle_x_2, bottle_y_2);
                            end
                            3: begin
                                dist_bin[3] <= calc_distance(tx, ty, bottle_x_3, bottle_y_3);
                                dist_adil[3] <= calc_distance(ax, ay, bottle_x_3, bottle_y_3);
                                dist_bera[3] <= calc_distance(bx, by, bottle_x_3, bottle_y_3);
                            end
                            4: begin
                                dist_bin[4] <= calc_distance(tx, ty, bottle_x_4, bottle_y_4);
                                dist_adil[4] <= calc_distance(ax, ay, bottle_x_4, bottle_y_4);
                                dist_bera[4] <= calc_distance(bx, by, bottle_x_4, bottle_y_4);
                            end
                            5: begin
                                dist_bin[5] <= calc_distance(tx, ty, bottle_x_5, bottle_y_5);
                                dist_adil[5] <= calc_distance(ax, ay, bottle_x_5, bottle_y_5);
                                dist_bera[5] <= calc_distance(bx, by, bottle_x_5, bottle_y_5);
                            end
                            6: begin
                                dist_bin[6] <= calc_distance(tx, ty, bottle_x_6, bottle_y_6);
                                dist_adil[6] <= calc_distance(ax, ay, bottle_x_6, bottle_y_6);
                                dist_bera[6] <= calc_distance(bx, by, bottle_x_6, bottle_y_6);
                            end
                            7: begin
                                dist_bin[7] <= calc_distance(tx, ty, bottle_x_7, bottle_y_7);
                                dist_adil[7] <= calc_distance(ax, ay, bottle_x_7, bottle_y_7);
                                dist_bera[7] <= calc_distance(bx, by, bottle_x_7, bottle_y_7);
                            end
                        endcase
                        counter <= counter + 6'd1;
                    end else begin
                        counter <= 6'd0;
                        state <= CALC_SAVINGS;
                    end
                end
                
                CALC_SAVINGS: begin
                    if (counter < num_bottles) begin
                        if (counter == 6'd0) begin
                            best_savings_adil <= savings_adil[0];
                            second_best_savings_adil <= 64'sd0;
                            best_idx_adil <= 3'd0;
                            second_best_idx_adil <= 3'd0;
                            best_savings_bera <= savings_bera[0];
                            second_best_savings_bera <= 64'sd0;
                            best_idx_bera <= 3'd0;
                            second_best_idx_bera <= 3'd0;
                        end else begin
                            // Adil
                            if (savings_adil[counter] > best_savings_adil) begin
                                second_best_savings_adil <= best_savings_adil;
                                second_best_idx_adil <= best_idx_adil;
                                best_savings_adil <= savings_adil[counter];
                                best_idx_adil <= counter[2:0];
                            end else if (savings_adil[counter] > second_best_savings_adil) begin
                                second_best_savings_adil <= savings_adil[counter];
                                second_best_idx_adil <= counter[2:0];
                            end
                            // Bera
                            if (savings_bera[counter] > best_savings_bera) begin
                                second_best_savings_bera <= best_savings_bera;
                                second_best_idx_bera <= best_idx_bera;
                                best_savings_bera <= savings_bera[counter];
                                best_idx_bera <= counter[2:0];
                            end else if (savings_bera[counter] > second_best_savings_bera) begin
                                second_best_savings_bera <= savings_bera[counter];
                                second_best_idx_bera <= counter[2:0];
                            end
                        end
                        counter <= counter + 6'd1;
                    end else begin
                        counter <= 6'd0;
                        state <= SELECT_TASKS;
                    end
                end
                
                SELECT_TASKS: begin
                    // Calculate max savings
                    // Option 1: Adil takes best, Bera takes best (if different bottles)
                    // Option 2: Adil takes best, Bera takes second best
                    // Option 3: Adil takes second best, Bera takes best
                    // Option 4: Adil takes best only, Bera does nothing
                    // Option 5: Bera takes best only, Adil does nothing
                    
                    max_savings <= 64'sd0;
                    
                    // Option 1: Different best bottles
                    if (best_idx_adil != best_idx_bera) begin
                        if (best_savings_adil + best_savings_bera > max_savings) begin
                            max_savings <= best_savings_adil + best_savings_bera;
                        end
                    end
                    
                    // Option 2: Adil best, Bera second best
                    if (best_savings_adil + second_best_savings_bera > max_savings) begin
                        max_savings <= best_savings_adil + second_best_savings_bera;
                    end
                    
                    // Option 3: Adil second best, Bera best
                    if (second_best_savings_adil + best_savings_bera > max_savings) begin
                        max_savings <= second_best_savings_adil + best_savings_bera;
                    end
                    
                    // Option 4: Only Adil takes best
                    if (best_savings_adil > max_savings) begin
                        max_savings <= best_savings_adil;
                    end
                    
                    // Option 5: Only Bera takes best
                    if (best_savings_bera > max_savings) begin
                        max_savings <= best_savings_bera;
                    end
                    
                    state <= CALC_RESULT;
                end
                
                CALC_RESULT: begin
                    // Base cost = 2 * sum of all distances from bin to bottles
                    base_cost_sum <= 64'd0;
                    counter <= 6'd0;
                    state <= FINISH;
                end
                
                FINISH: begin
                    if (counter < num_bottles) begin
                        base_cost_sum <= base_cost_sum + (dist_bin[counter] << 1);
                        counter <= counter + 6'd1;
                    end else begin
                        total_distance <= base_cost_sum - max_savings[63:0];
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule