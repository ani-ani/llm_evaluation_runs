module ice_cream_optimizer (
    input clk,
    input rst_n, // Active-low reset
    input start,
    input [7:0] num_scoops,
    input [7:0] cost_per_scoop,
    input [7:0] cost_cone,
    input [3:0][7:0] base_tastiness,
    input [3:0][3:0][15:0] interaction,
    output reg [15:0] max_ratio,
    output reg done
);

// Registers
reg [31:0] current_tastiness;
reg [15:0] current_cost;
reg [1:0] prev_flavor;
reg [4:0] current_scoop;
reg [15:0] max_ratio_reg;
reg done_reg;
reg [2:0] state;

// Outputs
assign max_ratio = max_ratio_reg;
assign done = done_reg;

// State parameters
localparam IDLE = 3'd0;
localparam INIT = 3'd1;
localparam PROCESSING = 3'd2;
localparam DONE_STATE = 3'd3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_tastiness <= 32'd0;
        current_cost <= 16'd0;
        prev_flavor <= 2'd0;
        current_scoop <= 5'd0;
        max_ratio_reg <= 16'd0;
        done_reg <= 1'b0;
        state <= IDLE;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= INIT;
            end else begin
                state <= IDLE;
            end
        end else if (state == INIT) begin
            current_cost <= cost_cone;
            current_tastiness <= 32'd0;
            prev_flavor <= 2'd0;
            current_scoop <= 1;
            if (num_scoops == 0) begin
                done_reg <= 1'b1;
                state <= DONE_STATE;
            end else begin
                state <= PROCESSING;
            end
        end else if (state == PROCESSING) begin
            if (current_scoop > num_scoops) begin
                state <= DONE_STATE;
                done_reg <= 1'b1;
            end else begin
                integer best_flavor = 0;
                integer candidate_t [3:0];
                integer candidate_c [3:0];
                for (int i=0; i<4; i=i+1) begin
                    candidate_t[i] = current_tastiness + base_tastiness[i];
                    if (current_scoop > 1) begin
                        candidate_t[i] = candidate_t[i] + interaction[prev_flavor][i];
                    end
                    candidate_c[i] = current_cost + cost_per_scoop;
                end

                best_flavor = 0;
                for (int i=1; i<4; i=i+1) begin
                    if (candidate_t[i] * candidate_c[best_flavor] > candidate_t[best_flavor] * candidate_c[i]) begin
                        best_flavor = i;
                    end
                end

                integer new_tastiness;
                integer new_cost;
                new_tastiness = current_tastiness + base_tastiness[best_flavor];
                if (current_scoop > 1) begin
                    new_tastiness = new_tastiness + interaction[prev_flavor][best_flavor];
                end
                new_cost = current_cost + cost_per_scoop;

                integer ratio_val;
                if (new_cost == 0) begin
                    ratio_val = 0;
                end else begin
                    ratio_val = (new_tastiness << 8) / new_cost;
                end

                if (ratio_val > max_ratio_reg) begin
                    max_ratio_reg <= ratio_val > 16'd65535 ? 16'd65535 : ratio_val;
                end else begin
                    max_ratio_reg <= max_ratio_reg;
                end

                current_tastiness <= new_tastiness;
                current_cost <= new_cost;
                prev_flavor <= best_flavor;
                current_scoop <= current_scoop + 1;
                state <= PROCESSING;
            end
        end else if (state == DONE_STATE) begin
            state <= DONE_STATE;
        end
    end
endmodule