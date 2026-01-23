module cone_lsa ( input clk, input rst_n, input start, input [15:0] r, input [15:0] h, output reg [31:0] result, output reg done );
localparam PI = 205887; // 3.14159 * 65536
localparam IDLE = 3'd0, PREPARE = 3'd1, SQRT_LOOP = 3'd2, MULTIPLY = 3'd3, DONE = 3'd4;
reg [2:0] state, next_state;
reg [31:0] r_scaled, h_scaled, r_sq, h_sq, sum_rh, sqrt_val, product;
reg [31:0] intermediate, result_reg;
reg done_reg;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
        r_scaled <= 32'd0;
        h_scaled <= 32'd0;
        r_sq <= 32'd0;
        h_sq <= 32'd0;
        sum_rh <= 32'd0;
        sqrt_val <= 32'd0;
        product <= 32'd0;
        intermediate <= 32'd0;
        result_reg <= 32'd0;
        done_reg <= 1'b0;
    end else begin
        if (state == DONE) begin
            next_state <= DONE;
        end else begin
            state <= next_state;
        end
        result_reg <= intermediate;
        done_reg <= done;
    end
end
always_comb begin
    next_state = state;
    done = 1'b0;
    intermediate = 32'd0;
    case (state)
        IDLE: begin
            if (start) begin
                next_state = PREPARE;
            end
        end
        PREPARE: begin
            r_scaled = (r << 16) >> 10; // (r * 65536) / 1024 = r * 64
            h_scaled = (h << 16) >> 10;
            r_sq = r_scaled * r_scaled;
            h_sq = h_scaled * h_scaled;
            sum_rh = r_sq + h_sq;
            next_state = SQRT_LOOP;
        end
        SQRT_LOOP: begin
            next_state = MULTIPLY;
        end
        MULTIPLY: begin
            intermediate = PI * r_scaled; // Incorrect
            next_state = DONE;
            done = 1'b1;
        end
        DONE: begin
            done = 1'b1;
        end
        default: next_state = IDLE;
    endcase
end
assign result = result_reg;
assign done = done_reg;
endmodule