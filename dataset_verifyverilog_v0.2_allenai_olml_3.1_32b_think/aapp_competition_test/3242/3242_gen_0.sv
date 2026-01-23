module find_min_energy (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_boxes,
    input [15:0] target_prob,
    input [9:0] energy_in,
    input [15:0] prob_in,
    input load_valid,
    output reg [9:0] min_energy,
    output reg valid
);

localparam IDLE = 2'd0;
localparam LOAD_STATE = 2'd1;
localparam WAIT_FOR_START = 2'd2;
localparam PROCESSING = 2'd3;
localparam DONE_STATE = 2'd4;

reg [1:2] state_reg;
reg [7:0] box_count;
reg [9:0] box_energy [7:0];
reg [15:0] box_prob [7:0];
reg [13:0] dp [0:2048];
reg [9:0] min_energy_reg;
reg valid_reg;

// Default assignments
assign min_energy = min_energy_reg;
assign valid = valid_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        box_count <= 0;
        min_energy_reg <= 0;
        valid_reg <= 0;
        box_energy[0] <= 0;
        box_energy[1] <= 0;
        box_energy[2] <= 0;
        box_energy[3] <= 0;
        box_energy[4] <= 0;
        box_energy[5] <= 0;
        box_energy[6] <= 0;
        box_energy[7] <= 0;
        box_prob[0] <= 0;
        box_prob[1] <= 0;
        box_prob[2] <= 0;
        box_prob[3] <= 0;
        box_prob[4] <= 0;
        box_prob[5] <= 0;
        box_prob[6] <= 0;
        box_prob[7] <= 0;
        dp[0] <= 0;
    end else begin
        if (state_reg == IDLE) begin
            if (load_valid && !start) begin
                state_reg <= LOAD_STATE;
            end
        end else if (state_reg == LOAD_STATE) begin
            if (load_valid && box_count < num_boxes) begin
                box_energy[box_count] <= energy_in;
                box_prob[box_count] <= prob_in;
                box_count <= box_count + 1;
            end
            if (box_count == num_boxes) begin
                state_reg <= WAIT_FOR_START;
            end
        end else if (state_reg == WAIT_FOR_START) begin
            if (start) begin
                state_reg <= PROCESSING;
            end
        end else if (state_reg == PROCESSING) begin
            state_reg <= DONE_STATE;
        end
    end
end

assign load_ready = (state_reg == LOAD_STATE) && (box_count < num_boxes);

if (state_reg == DONE_STATE) begin
    min_energy_reg <= 0;
    valid_reg <= 1;
end

endmodule