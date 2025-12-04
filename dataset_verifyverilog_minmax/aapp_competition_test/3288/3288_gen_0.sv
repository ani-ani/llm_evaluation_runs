module incremental_double_free_string (
  input clk,
  input rst_n,
  input start,
  input [1:0] k,
  input [9:0] n,
  output reg [14:0] string_out,
  output reg done,
  output reg err
);

  // Calculate outputs combinationaly when start is asserted.
  // Pipeline them to meet 1-cycle latency.
  always @(posedge clk) begin
    if (!rst_n) begin
      string_out <= 15'b0;
      done <= 1'b0;
      err  <= 1'b0;
    end else if (start) begin
      if (k == 2'd1) begin
        if (n <= 10'd26) begin
          string_out <= {10'b0, n[4:0]}; // single character in [4:0]
          err <= 1'b0;
        end else begin
          string_out <= 15'b0;
          err <= 1'b1;
        end
        done <= 1'b1;
      end else if (k == 2'd2) begin
        if (n <= 10'd650) begin
          reg [9:0] temp;
          reg [4:0] first_char;
          reg [4:0] second_char;
          reg [4:0] rem;

          temp = n - 1;
          first_char = (temp / 5'd25) + 5'd1;
          rem = temp % 5'd25;

          // Ensure A and B are distinct for A-B-A format
          if (rem >= (first_char - 1))
            second_char = rem + 5'd2;
          else
            second_char = rem + 5'd1;

          // Guard against accidental equality (shouldn't happen with above logic)
          if (second_char == first_char) begin
            string_out <= 15'b0;
            err <= 1'b1;
          end else begin
            string_out <= {first_char, second_char, first_char};
            err <= 1'b0;
          end
        end else begin
          string_out <= 15'b0;
          err <= 1'b1;
        end
        done <= 1'b1;
      end else begin
        // Invalid k
        string_out <= 15'b0;
        err <= 1'b1;
        done <= 1'b1;
      end
    end else begin
      // No start: hold current outputs (keeps done/err/string_out stable)
      string_out <= string_out;
      done <= done;
      err <= err;
    end
  end
endmodule