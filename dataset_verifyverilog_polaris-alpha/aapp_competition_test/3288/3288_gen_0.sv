module incremental_double_free_string(
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire [1:0] k,
  input wire [9:0] n,
  output reg [14:0] string_out,
  output reg done,
  output reg err
);

  // Internal combinational signals
  reg [14:0] next_string_out;
  reg next_done;
  reg next_err;

  reg [9:0] temp;
  reg [4:0] first_char;
  reg [4:0] second_char;
  reg [4:0] rem;

  // Combinational logic
  always @* begin
    // Default values: hold previous outputs unless start is asserted
    next_string_out = string_out;
    next_done       = 1'b0;
    next_err        = 1'b0;

    if (start) begin
      next_done       = 1'b1;
      next_string_out = 15'd0;
      next_err        = 1'b0;

      case (k)
        2'd1: begin
          if (n >= 10'd1 && n <= 10'd26) begin
            next_string_out[4:0]  = n[4:0];
            next_string_out[14:5] = 10'd0;
            next_err              = 1'b0;
          end else begin
            next_string_out = 15'd0;
            next_err        = 1'b1;
          end
        end

        2'd2: begin
          if (n >= 10'd1 && n <= 10'd650) begin
            temp       = n - 10'd1;
            first_char = (temp / 10'd25) + 5'd1;
            rem        = temp % 10'd25;
            if (rem >= (first_char - 5'd1))
              second_char = rem + 5'd2;
            else
              second_char = rem + 5'd1;

            next_string_out = {first_char, second_char, first_char};
            next_err        = 1'b0;
          end else begin
            next_string_out = 15'd0;
            next_err        = 1'b1;
          end
        end

        default: begin
          next_string_out = 15'd0;
          next_err        = 1'b1;
        end
      endcase
    end
  end

  // Sequential logic: outputs valid 1 clock cycle after start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      string_out <= 15'd0;
      done       <= 1'b0;
      err        <= 1'b0;
    end else begin
      string_out <= next_string_out;
      done       <= next_done;
      err        <= next_err;
    end
  end

endmodule