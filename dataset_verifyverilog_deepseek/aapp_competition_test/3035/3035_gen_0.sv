module lemonade_trader (
  input clk,
  input rst_n,
  input start,
  input [3:0] color_ids [0:7],
  input [31:0] rates [0:7],
  input [2:0] num_children,
  output reg [31:0] max_blue_q16,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam EVAL = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, next_state;
  reg [7:0] mask_counter;
  reg [31:0] max_blue_reg;
  reg start_prev;

  wire start_rising = start && !start_prev;

  logic [31:0] temp_amount_cmb;
  logic [3:0] temp_color_cmb;

  always_comb begin
    temp_amount_cmb = 32'h00010000;
    temp_color_cmb = 4'd0;
    for (int i=0; i < num_children; i++) begin
      if (mask_counter[i]) begin
        automatic logic [63:0] product = temp_amount_cmb * rates[i];
        temp_amount_cmb = product[47:16];
        temp_color_cmb = color_ids[i];
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      mask_counter <= 8'b0;
      max_blue_reg <= 32'b0;
      done <= 1'b0;
      max_blue_q16 <= 32'b0;
      start_prev <= 1'b0;
    end else begin
      start_prev <= start;
      case (state)
        IDLE: begin
          done <= 1'b0;
          max_blue_q16 <= (max_blue_q16 > 32'h000A0000) ? 32'h000A0000 : max_blue_q16;
          if (start_rising) begin
            state <= EVAL;
            mask_counter <= 8'b0;
            max_blue_reg <= 32'b0;
          end
        end
        EVAL: begin
          if (temp_color_cmb == 4'd1 && temp_amount_cmb > max_blue_reg) begin
            max_blue_reg <= temp_amount_cmb;
          end
          if (mask_counter == (1 << num_children) - 1) begin
            state <= DONE;
            done <= 1'b1;
            max_blue_q16 <= (max_blue_reg > 32'h000A0000) ? 32'h000A0000 : max_blue_reg;
          end else begin
            mask_counter <= mask_counter + 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule