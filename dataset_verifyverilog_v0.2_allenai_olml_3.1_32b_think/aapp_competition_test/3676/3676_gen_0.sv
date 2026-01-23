module count_polygons (input clk, input rst_n, input start, input [2:0] R, input [2:0] C, output reg [15:0] result, output reg done);
reg [2:0] stored_R = 3'b0, stored_C = 3'b0;
reg [15:0] current_mask = 4'd1, max_mask = 16'd0, result_reg = 16'd0, visited =16'd0;
reg [3:0] loop_cnt =4'd0;
reg changed =1'b0;
reg [15:0] first_bit =16'd0, shift_cnt =4'd0, temp =16'd0;
reg [2:0] state = 3'd0;
parameter IDLE = 3'd0, INIT=3'd1, ITERATE=3'd2, CHECK=3'd3, NEXT_MASK=3'd4, DONE=3'd5;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        stored_R <=3'b0;
        stored_C <=3'b0;
        current_mask <=4'd1;
        max_mask <=16'd0;
        result_reg <=16'd0;
        done <=1'b0;
        visited <=16'd0;
        loop_cnt <=4'd0;
        changed <=1'b0;
        first_bit <=16'd0;
        shift_cnt <=4'd0;
        temp <=16'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= INIT;
            end
            INIT: begin
                stored_R <= R;
                stored_C <= C;
                localparam integer exp = stored_R * stored_C;
                max_mask <= (1 << exp) -1;
                current_mask <=4'd1;
                state <= ITERATE;
            end
            ITERATE: begin
                if (current_mask < max_mask) begin
                    state <= CHECK;
                end else begin
                    state <= DONE;
                end
            end
            CHECK: begin
                bit is_connected;
                is_connected = (current_mask & (current_mask -1)) == 16'd0;
                if (is_connected) begin
                    result_reg <= result_reg +1;
                end
                state <= NEXT_MASK;
            end
            NEXT_MASK: begin
                current_mask <= current_mask +1;
                state <= ITERATE;
            end
            DONE: begin
                done <= 1'b1;
            end
        endcase
    end
end
assign result = result_reg;
assign done = done;
endmodule