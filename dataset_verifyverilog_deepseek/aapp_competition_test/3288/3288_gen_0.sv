module incremental_double_free_string(input clk, rst_n, start,
                            input [1:0] k,
                            input [9:0] n,
                            output reg [14:0] string_out,
                            output reg done,
                            output reg err);

  reg [1:0] k_reg;
  reg [9:0] n_reg;
  reg start_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_reg <= 0;
      k_reg <= 0;
      n_reg <= 0;
      string_out <= 0;
      done <= 0;
      err <= 0;
    end
    else begin
      start_reg <= start;
      if (start) begin
        k_reg <= k;
        n_reg <= n;
      end

      // Default assignments
      done <= 0;
      err <= 0;

      if (start_reg) begin
        case (k_reg)
          2'b01: begin // k=1
            if (n_reg >= 1 && n_reg <= 26) begin
              string_out <= {10'b0, n_reg[4:0]};
              done <= 1;
            end
            else begin
              err <= 1;
              done <= 1;
              string_out <= 0;
            end
          end
          
          2'b10: begin // k=2
            if (n_reg >= 1 && n_reg <= 650) begin
              logic [9:0] temp;
              logic [4:0] first_char, second_char;
              logic [4:0] rem;
              
              temp = n_reg - 10'd1;
              first_char = (temp / 25) + 1;
              rem = temp % 25;
              second_char = (rem >= (first_char - 1)) ? (rem + 2) : (rem + 1);
              string_out <= {first_char, second_char, first_char};
              done <= 1;
            end
            else begin
              err <= 1;
              done <= 1;
              string_out <= 0;
            end
          end
          
          default: begin // Invalid k
            err <= 1;
            done <= 1;
            string_out <= 0;
          end
        endcase
      end
    end
  end
endmodule