module hill_counter(input clk, input rst_n, input start, input [15:0] n, output reg [31:0] result, output reg done);

reg [2:0] state;
reg [3:0] digits;
reg [31:0] result_reg;
reg done_reg;

localparam IDLE = 3'd0;
localparam DIGITIZE = 3'd1;
localparam CHECK_HILL = 3'd2;
localparam COUNT_HILL = 3'd3;
localparam DONE = 3'd4;

always @(posedge clk) begin
  if (!rst_n) begin
    state <= IDLE;
    digits <= 4'd0;
    result_reg <= 32'd0;
    done_reg <= 1'b0;
  end else begin
    case (state)
      IDLE: if (start) state <= DIGITIZE; else state <= IDLE;
      DIGITIZE: begin
        digits <= {n[15:12], n[11:8], n[7:4], n[3:0]};
        state <= CHECK_HILL;
      end
      CHECK_HILL: begin
        wire [3:0] first_non_zero;
        wire is_zero;
        assign first_non_zero = 4'd4;
        if (digits[0] !=4'd0) first_non_zero =4'd0;
        else if (digits[1] !=4'd0) first_non_zero =4'd1;
        else if (digits[2] !=4'd0) first_non_zero =4'd2;
        else if (digits[3] !=4'd0) first_non_zero =4'd3;
        assign is_zero = (first_non_zero ==4'd4);
        if (is_zero) begin
          result_reg <= 32'd0xFFFFFFFF;
          state <= DONE;
          done_reg <= 1'b1;
        end else begin
          reg [3:0] current_prev;
          reg [1:0] phase;
          reg valid =1'b1;
          initial current_prev = digits[first_non_zero];
          initial phase = 2'b00;
          for (int i = first_non_zero +1; i <=3; i++) begin
            if (digits[i] > current_prev) begin
              if (phase == 2'b10) valid =1'b0;
              phase = 2'b01;
            end else if (digits[i] < current_prev) begin
              phase = 2'b10;
            end
            current_prev = digits[i];
            if (!valid) break;
          end
          if (valid) state <= COUNT_HILL; else begin
            result_reg <= 32'd0xFFFFFFFF;
            state <= DONE;
            done_reg <= 1'b1;
          end
        end
      end
      COUNT_HILL: begin
        result_reg <= 32'd0;
        state <= DONE;
        done_reg <= 1'b1;
      end
      DONE: state <= DONE;
    endcase
  end
end

assign result = result_reg;
assign done = done_reg;
endmodule