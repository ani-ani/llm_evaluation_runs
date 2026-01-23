module rect_area_calculator (
    input clk,
    input rst_n,
    input start,
    input [31:0] x1,
    input [31:0] y1,
    input [31:0] x2,
    input [31:0] y2,
    input [1:0] rect_idx,
    input rect_valid,
    output reg [31:0] total_area,
    output reg done,
    output reg [1:0] state_out
);

reg [31:0] rect_x1 [3];
reg [31:0] rect_y1 [3];
reg [31:0] rect_x2 [3];
reg [31:0] rect_y2 [3];
reg [2:0] rect_count;
reg [6:0] compute_counter;
reg [1:0] state;

assign state_out = state;
assign done = (state == 2'b11);

always_ff @(posedge clk) begin
    if (!rst_n) begin
        rect_x1 <= 32'd0;
        rect_y1 <= 32'd0;
        rect_x2 <= 32'd0;
        rect_y2 <= 32'd0;
        rect_count <= 3'd0;
        compute_counter <= 7'd0;
        state <= 2'b00;
        total_area <= 32'd0;
    end else begin
        if (rect_valid && (rect_idx >= 0 && rect_idx <= 3) && rect_count < 4) begin
            rect_x1[rect_idx] <= x1;
            rect_y1[rect_idx] <= y1;
            rect_x2[rect_idx] <= x2;
            rect_y2[rect_idx] <= y2;
            rect_count <= rect_count + 1;
        end

        case (state)
            2'b00: // IDLE
                if (rect_count == 4) begin
                    state <= 2'b10; // Move to COMPUTING
                end
            2'b10: // COMPUTING
                if (compute_counter == 64) begin
                    state <= 2'b11; // Move to DONE
                end else begin
                    compute_counter <= compute_counter + 1;
                end
            2'b11: // DONE
                state <= 2'b11;
            default: state <= 2'b00;
        endcase

        total_area <= 32'd0;
    end
endmodule