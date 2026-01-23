module wheel_rotations_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0][1:0] wheel0, wheel1, wheel2,
    output reg [3:0] result,
    output reg done,
    output reg valid
);

reg [2:0] state;
reg [3:0] min_cost;
reg [2:0] current_offset1;

localparam state_IDLE = 3'b000;
localparam state_PREP_OFFSET1 = 3'b001;
localparam state_CHECK_OFFSET2 = 3'b010;
localparam state_NEXT_OFFSET2 = 3'b011;
localparam state_NEXT_OFFSET1 = 3'b100;
localparam state_DONE = 3'b101;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= state_IDLE;
        min_cost <= 4'd15;
        current_offset1 <= 3'd0;
        done <= 1'b0;
        valid <= 1'b0;
    end else begin
        if (state == state_IDLE) begin
            if (start) state <= state_PREP_OFFSET1;
        end else if (state == state_PREP_OFFSET1) begin
            state <= state_CHECK_OFFSET2;
        end else if (state == state_CHECK_OFFSET2) begin
            state <= state_NEXT_OFFSET2;
        end else if (state == state_NEXT_OFFSET2) begin
            state <= state_NEXT_OFFSET1;
        end else if (state == state_NEXT_OFFSET1) begin
            current_offset1 <= current_offset1 + 1;
            if (current_offset1 < 8) begin
                state <= state_PREP_OFFSET1;
            end else begin
                state <= state_DONE;
                done <= 1'b1;
                valid <= (min_cost != 4'd15);
            end
        end
    end
end

// Combinational assignments (dummy)
assign result = min_cost;

endmodule