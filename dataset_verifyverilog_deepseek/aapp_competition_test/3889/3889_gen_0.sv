module puppy_recolor_check(
  input clk,
  input rst_n,
  input start,
  input [3:0] valid_length,
  input [127:0] string_in,
  output reg result,
  output reg done
);

  reg [3:0] valid_length_reg;
  reg [127:0] string_in_reg;
  reg compute_done;
  wire [4:0] counts [0:25];
  wire any_ge2;
  wire comp_result;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      valid_length_reg <= 4'd0;
      string_in_reg <= 128'd0;
      compute_done <= 1'b0;
    end else begin
      if (start) begin
        valid_length_reg <= valid_length;
        string_in_reg <= string_in;
        compute_done <= 1'b1;
      end else begin
        compute_done <= 1'b0;
      end
    end
  end

  genvar c, i;
  generate
    for (c = 0; c < 26; c = c + 1) begin : gen_char_counters
      wire [15:0] hit;
      for (i = 0; i < 16; i = i + 1) begin : gen_pos_hits
        wire [7:0] char_i = string_in_reg[i*8 +: 8];
        assign hit[i] = (i < valid_length_reg) && (char_i == (8'h61 + c));
      end
      assign counts[c] = hit[0] + hit[1] + hit[2] + hit[3] + hit[4] + hit[5] + hit[6] + hit[7]
                       + hit[8] + hit[9] + hit[10] + hit[11] + hit[12] + hit[13] + hit[14] + hit[15];
    end
  endgenerate

  wire [25:0] ge2;
  generate
    for (c = 0; c < 26; c = c + 1) begin : gen_ge2
      assign ge2[c] = (counts[c] >= 2);
    end
  endgenerate
  assign any_ge2 = |ge2;
  assign comp_result = (valid_length_reg == 4'd1) || any_ge2;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      result <= 1'b0;
      done <= 1'b0;
    end else begin
      if (compute_done) begin
        result <= comp_result;
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule