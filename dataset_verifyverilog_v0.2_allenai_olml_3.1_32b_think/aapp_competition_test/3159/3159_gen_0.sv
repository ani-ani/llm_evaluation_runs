module ad_remover (input clk, input rst_n, input start, input [7:0] char_in [31:0][31:0], output reg [7:0] char_out [31:0][31:0], output reg done);
reg [3:0] state;
reg [7:0] char_out_reg [31:0][31:0];
reg [15:0] cycle_count;
reg processing_done;
parameter IDLE = 4'd0;
parameter PARSE_IMAGES = 4'd1;
parameter CHECK_BANNED = 4'd2;
parameter MARK_ADS = 4'd3;
parameter REMOVE_ADS = 4'd4;
parameter DONE_STATE = 4'd5;
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        char_out_reg <= char_in;
        cycle_count <= 16'd0;
        processing_done <= 1'b0;
        done <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= PARSE_IMAGES;
                cycle_count <= 16'd0;
            end
        end else if (state == PARSE_IMAGES) begin
            state <= CHECK_BANNED;
        end else if (state == CHECK_BANNED) begin
            state <= MARK_ADS;
        end else if (state == MARK_ADS) begin
            state <= REMOVE_ADS;
        end else if (state == REMOVE_ADS) begin
            state <= DONE_STATE;
        end else if (state == DONE_STATE) begin
            if (cycle_count < 10000) begin
                cycle_count <= cycle_count + 1;
            end else begin
                processing_done <= 1'b1;
                done <= 1'b1;
            end
        end
    end
end
assign char_out = processing_done ? char_out_reg : char_in;
endmodule