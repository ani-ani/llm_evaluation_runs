module buffet_optimizer(
    input clk,
    input rst_n,
    input start,
    input [7:0] dish_count,
    input [7:0] total_weight,
    input [7:0] dish_info_index,
    input [47:0] dish_data,
    input dish_data_valid,
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // State encoding
    reg [2:0] state;
    localparam IDLE = 3'd0;
    localparam LOAD_DISCRETE = 3'd1;
    localparam COMPUTE = 3'd2;
    localparam DONE = 3'd3;

    // Dish storage
    reg [15:0] d_weight [0:7];
    reg [31:0] d_t [0:7];
    reg [31:0] d_dt [0:7];
    reg [2:0] d_count;

    reg [31:0] c_t [0:7];
    reg [31:0] c_dt [0:7];
    reg [2:0] c_count;

    // DP arrays
    reg [31:0] dp_tastiness [0:128];
    reg dp_valid [0:128];

    // Compute state variables
    reg [7:0] current_weight;
    reg [2:0] dish_idx;
    reg [2:0] compute_step;
    reg [7:0] rem_weight;
    reg signed [31:0] best_total;
    reg [7:0] check_idx;

    // Fixed-point helpers (inline for synthesis)
    // mul_fixed: Q16.16 * Q16.16 -> Q32.32, take upper 32 bits
    wire signed [63:0] mul_temp;
    assign mul_temp = $signed({{32{1'b0}}, 32'h00000000}) * $signed({{32{1'b0}}, 32'h00000000}); // dummy for context

    function [31:0] mul_fixed;
        input [31:0] a;
        input [31:0] b;
        reg signed [63:0] prod;
        begin
            prod = $signed(a) * $signed(b);
            mul_fixed = prod[47:16]; // Shift right by 16
        end
    endfunction

    function [31:0] sub_fixed;
        input [31:0] a;
        input [31:0] b;
        begin
            sub_fixed = a - b;
        end
    endfunction

    function [31:0] div_fixed_int;
        input [31:0] a;
        input [7:0] b;
        begin
            if (b == 0) div_fixed_int = 32'h7FFFFFFF; // Max positive
            else div_fixed_int = $signed(a) / $signed({24'b0, b});
        end
    endfunction

    function [31:0] int_to_fixed;
        input [15:0] int_val;
        begin
            int_to_fixed = {int_val, 16'h0000};
        end
    endfunction

    // Continuous calculation helper
    function [31:0] calc_continuous;
        input [7:0] weight;
        input [31:0] t;
        input [31:0] dt;
        reg [31:0] x;
        reg [31:0] x_sq;
        reg [31:0] term1;
        reg [31:0] term2;
        reg [31:0] half_dt;
        begin
            // T(x) = t*x - (dt*x^2)/2
            if ($signed(dt) <= 0) begin
                // Constant or increasing (saturate at weight)
                calc_continuous = mul_fixed(t, int_to_fixed(weight));
            end else begin
                x = int_to_fixed(weight);
                term1 = mul_fixed(t, x);
                
                // x^2
                x_sq = mul_fixed(x, x);
                
                // dt*x^2 (shifted already by mul_fixed)
                term2 = mul_fixed(dt, x_sq);
                
                // divide term2 by 2 (shift right 1)
                term2 = term2 >>> 1;
                
                calc_continuous = sub_fixed(term1, term2);
            end
        end
    endfunction

    // Combinational block to find best continuous value for a weight
    reg [31:0] best_cont_val;
    always @(*) begin
        best_cont_val = 32'h80000000;
        for (integer j = 0; j < c_count; j = j + 1) begin
            if ($signed(c_t[j]) > 0) begin
                reg [31:0] val = calc_continuous(rem_weight, c_t[j], c_dt[j]);
                if ($signed(val) > $signed(best_cont_val)) begin
                    best_cont_val = val;
                end
            end
        end
        if (c_count == 0 || $signed(best_cont_val) == 32'h80000000) best_cont_val = 0;
    end

    // Main State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            result <= 32'h00000000;
            d_count <= 3'd0;
            c_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        state <= LOAD_DISCRETE;
                        d_count <= 3'd0;
                        c_count <= 3'd0;
                    end
                end

                LOAD_DISCRETE: begin
                    if (dish_data_valid) begin
                        if (dish_data[47]) begin
                            // Continuous
                            if (c_count < 8) begin
                                c_t[c_count] <= {16'h0000, dish_data[31:16]};
                                c_dt[c_count] <= {16'h0000, dish_data[15:0]};
                                c_count <= c_count + 1;
                            end
                        end else begin
                            // Discrete
                            if (d_count < 8) begin
                                d_weight[d_count] <= dish_data[47:32];
                                d_t[d_count] <= {16'h0000, dish_data[31:16]};
                                d_dt[d_count] <= {16'h0000, dish_data[15:0]};
                                d_count <= d_count + 1;
                            end
                        end
                    end
                    
                    if (dish_info_index >= dish_count && dish_count != 0) begin
                        state <= COMPUTE;
                        compute_step <= 3'd0;
                        current_weight <= 8'd0;
                        dish_idx <= 3'd0;
                        // Initialize DP
                        dp_tastiness[0] <= 32'h00000000;
                        dp_valid[0] <= 1'b1;
                        for (integer i = 1; i < 129; i = i + 1) begin
                            dp_valid[i] <= 1'b0;
                        end
                    end else if (start == 1'b0 && state == LOAD_DISCRETE && dish_count == 0) begin
                         // Edge case: zero dishes
                         state <= IDLE;
                    end
                end

                COMPUTE: begin
                    case (compute_step)
                        3'd0: begin // Discrete Knapsack
                            if (dish_idx < d_count) begin
                                if (current_weight <= total_weight) begin
                                    // Check transitions
                                    reg [7:0] w = d_weight[dish_idx];
                                    if (w > 0 && (current_weight + w) <= total_weight && dp_valid[current_weight]) begin
                                        // Calculate current count for decay
                                        reg [7:0] count = 0;
                                        reg [7:0] temp_w = current_weight;
                                        while (temp_w >= w) begin
                                            temp_w = temp_w - w;
                                            count = count + 1;
                                        end
                                        
                                        // Tastiness for next item
                                        reg [31:0] item_t = sub_fixed(d_t[dish_idx], mul_fixed(int_to_fixed(count), d_dt[dish_idx]));
                                        reg [31:0] new_t = dp_tastiness[current_weight] + item_t;
                                        reg [7:0] new_w = current_weight + w;
                                        
                                        if (!dp_valid[new_w] || $signed(new_t) > $signed(dp_tastiness[new_w])) begin
                                            dp_tastiness[new_w] <= new_t;
                                            dp_valid[new_w] <= 1'b1;
                                        end
                                    end
                                    current_weight <= current_weight + 1;
                                end else begin
                                    current_weight <= 8'd0;
                                    dish_idx <= dish_idx + 1;
                                end
                            end else begin
                                compute_step <= 3'd1;
                                check_idx <= 8'd0;
                                best_total <= 32'h80000000;
                            end
                        end

                        3'd1: begin // Find max result with continuous
                            if (check_idx <= total_weight) begin
                                if (dp_valid[check_idx]) begin
                                    rem_weight <= total_weight - check_idx;
                                    compute_step <= 3'd2; // Wait for combinational calc
                                end else begin
                                    check_idx <= check_idx + 1;
                                end
                            end else begin
                                state <= DONE;
                                if ($signed(best_total) >= 0) begin
                                    result <= best_total;
                                    error <= 1'b0;
                                end else begin
                                    result <= 32'hFFFFFFFF;
                                    error <= 1'b1;
                                end
                            end
                        end

                        3'd2: begin // Process continuous result
                            // This step reads best_cont_val
                            reg signed [31:0] total = $signed(dp_tastiness[check_idx]) + $signed(best_cont_val);
                            if ($signed(total) > $signed(best_total)) begin
                                best_total <= total;
                            end
                            check_idx <= check_idx + 1;
                            compute_step <= 3'd1;
                        end
                    endcase
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
