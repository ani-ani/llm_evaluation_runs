module find_polly #(
    parameter N = 8,
    parameter WIDTH_ENERGY = 10,
    parameter WIDTH_PROB = 16,
    parameter WIDTH_RESULT = 13
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [WIDTH_ENERGY-1:0] energy [0:N-1],
    input wire [WIDTH_PROB-1:0] prob [0:N-1],
    input wire [WIDTH_PROB-1:0] P_target,
    output reg [WIDTH_RESULT-1:0] min_energy,
    output reg done
);

    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] INIT = 3'b001;
    localparam [2:0] COMPUTE_SUBSET = 3'b010;
    localparam [2:0] CHECK_BIT = 3'b011;
    localparam [2:0] UPDATE_RESULT = 3'b100;
    localparam [2:0] INCREMENT = 3'b101;
    localparam [2:0] DONE = 3'b110;

    reg [2:0] state;
    reg [7:0] subset_reg;
    reg [2:0] bit_index;
    reg [WIDTH_PROB-1:0] temp_prob_sum;
    reg [WIDTH_RESULT-1:0] temp_energy_sum;
    reg [WIDTH_RESULT-1:0] min_energy_reg;
    reg [WIDTH_PROB-1:0] P_target_reg;

    wire [WIDTH_PROB-1:0] prob_to_add;
    wire [WIDTH_RESULT-1:0] energy_to_add;
    wire subset_bit_set;
    wire [7:0] max_subset;

    assign max_subset = (1 << N) - 1;
    assign subset_bit_set = subset_reg[bit_index];
    assign prob_to_add = prob[bit_index];
    assign energy_to_add = energy[bit_index];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_reg <= 8'd0;
            bit_index <= 3'd0;
            temp_prob_sum <= 16'd0;
            temp_energy_sum <= 13'd0;
            min_energy_reg <= 13'd0;
            P_target_reg <= 16'd0;
            min_energy <= 13'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    min_energy_reg <= {WIDTH_RESULT{1'b1}};
                    subset_reg <= 8'd0;
                    P_target_reg <= P_target;
                    state <= COMPUTE_SUBSET;
                end
                
                COMPUTE_SUBSET: begin
                    temp_prob_sum <= 16'd0;
                    temp_energy_sum <= 13'd0;
                    bit_index <= 3'd0;
                    state <= CHECK_BIT;
                end
                
                CHECK_BIT: begin
                    if (subset_bit_set) begin
                        temp_prob_sum <= temp_prob_sum + prob_to_add;
                        temp_energy_sum <= temp_energy_sum + energy_to_add;
                    end
                    bit_index <= bit_index + 1'b1;
                    if (bit_index == N - 1) begin
                        state <= UPDATE_RESULT;
                    end else begin
                        state <= CHECK_BIT;
                    end
                end
                
                UPDATE_RESULT: begin
                    if (temp_prob_sum >= P_target_reg && temp_energy_sum < min_energy_reg) begin
                        min_energy_reg <= temp_energy_sum;
                    end
                    state <= INCREMENT;
                end
                
                INCREMENT: begin
                    subset_reg <= subset_reg + 8'd1;
                    if (subset_reg < max_subset) begin
                        state <= COMPUTE_SUBSET;
                    end else begin
                        state <= DONE;
                        min_energy <= min_energy_reg;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        state <= INIT;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule