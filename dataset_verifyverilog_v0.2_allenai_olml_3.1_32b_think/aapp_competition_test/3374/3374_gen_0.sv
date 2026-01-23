module uw_distance_calculator (
    input clk,
    input rst_n,
    input start,
    input [2:0] node_count,
    input [31:0] gravity_in,
    input node_valid,
    input [7:0] adjacency_in,
    input adj_valid,
    input [2:0] type_in,
    input type_valid,
    output reg [31:0] min_distance,
    output reg result_valid
);
// Internal registers
reg [31:0] original_grav [7:0];
reg [7:0] is_connected [7][7];
reg [2:0] state, next_state;
localparam STATE_IDLE = 3'd0, LOAD_GRAVITY=1, LOAD_ADJ=2, LOAD_TYPE=3, CALC=4, DEVICE=5, DONE=6;
reg [31:0] current_min;
reg [7:0] human_nodes, alien_nodes;
reg [2:0] gravity_counter, adj_counter, type_counter;
reg [7:0] modified_grav [7:0];

always @(posedge clk) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        current_min <= 32'd0;
        result_valid <= 1'b0;
        gravity_counter <= 3'd0;
        adj_counter <= 3'd0;
        type_counter <= 3'd0;
    end else begin
        state <= next_state;
    end
end

always @(*) begin
    next_state = state;
    if (state == STATE_IDLE) begin
        if (start) next_state = LOAD_GRAVITY;
    end
    // TODO: implement other states
end

assign result_valid = (state == DONE);
assign min_distance = current_min;

endmodule