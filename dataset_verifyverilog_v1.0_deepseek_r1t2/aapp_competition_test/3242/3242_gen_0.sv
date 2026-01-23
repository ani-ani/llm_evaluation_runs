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

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT = 3'd1;
localparam [2:0] COMPUTE_SUBSET = 3'd2;
localparam [2:0] CHECK_BIT = 3'd3;
localparam [2:0] UPDATE_RESULT = 3'd4;
localparam [2:0] INCREMENT = 3'd5;
localparam [2:0] DONE_STATE = 3'd6;

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
integer i;

assign max_subset = (8'd1 << N) - 8'd1;
assign subset_bit_set = subset_reg[bit_index];
assign prob_to_add = prob[bit_index];
assign energy_to_add = { {WIDTH_RESULT-WIDTH_ENERGY{1'b0}}, energy[bit_index] };

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        subset_reg <= 8'd0;
        bit_index <= 3'd0;
        temp_prob_sum <= {WIDTH_PROB{1'b0}};
        temp_energy_sum <= {WIDTH_RESULT{1'b0}};
        min_energy_reg <= {WIDTH_RESULT{1'b1}};
        P_target_reg <= {WIDTH_PROB{1'b0}};
        min_energy <= {WIDTH_RESULT{1'b0}};
        done <= 1'b0;
    end
    else begin
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
                temp_prob_sum <= {WIDTH_PROB{1'b0}};
                temp_energy_sum <= {WIDTH_RESULT{1'b0}};
                bit_index <= 3'd0;
                state <= CHECK_BIT;
            end
            
            CHECK_BIT: begin
                if (subset_bit_set) begin
                    temp_prob_sum <= temp_prob_sum + prob_to_add;
                    temp_energy_sum <= temp_energy_sum + energy_to_add;
                end
                
                if (bit_index == 3'd7) begin
                    state <= UPDATE_RESULT;
                end
                else begin
                    bit_index <= bit_index + 3'd1;
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
                end
                else begin
                    min_energy <= min_energy_reg;
                    state <= DONE_STATE;
                end
            end
            
            DONE_STATE: begin
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