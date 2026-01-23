module byteconn_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] digit [7:0],
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPUTE,
    FINALIZE
  } state_t;

  state_t state;
  reg [7:0] mask;
  reg [7:0] sum;
  reg [7:0] selected_digits;
  reg all_zeros;
  reg [7:0] i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      mask <= 0;
      sum <= 0;
      selected_digits <= 0;
      all_zeros <= 1;
      i <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE;
            mask <= 0;
            result <= 0;
            done <= 0;
          end
        end
        COMPUTE: begin
          // Calculate sum and check for all zeros
          sum <= 0;
          selected_digits <= 0;
          all_zeros <= 1;
          for (i = 0; i < 8; i = i + 1) begin
            if (mask[i]) begin
              sum <= sum + (digit[i] - 8'h30);
              selected_digits <= selected_digits + 1;
              if (digit[i] != 8'h30) begin
                all_zeros <= 0;
              end
            end
          end

          // Check validity and increment result if valid
          if ((sum % 3 == 0) && (selected_digits > 0) && (!all_zeros || (selected_digits == 1 && sum == 0))) begin
            result <= result + 1;
          end

          // Move to next mask
          if (mask == 8'hFF) begin
            state <= FINALIZE;
          end else begin
            mask <= mask + 1;
          end
        end
        FINALIZE: begin
          done <= 1;
          if (start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule