module crypto_subset_counter(
  input clk,
  input rst_n,
  input start,
  input [1:0] N,
  input [3:0] digit0,
  input [3:0] digit1,
  input [3:0] digit2,
  input [3:0] digit3,
  output reg [31:0] result,
  output reg done
);

  typedef enum {IDLE, PROCESSING} state_t;
  state_t state;

  reg [3:0] mask_counter;
  reg [31:0] count_reg;
  reg [5:0] cycle_counter;
  wire [3:0] max_mask = (4'b1 << N) - 1'b1;

  wire leading_zero = (mask_counter[0] & (digit0 == 4'b0)) | 
                     (~mask_counter[0] & mask_counter[1] & (digit1 == 4'b0)) | 
                     (~mask_counter[0] & ~mask_counter[1] & mask_counter[2] & (digit2 == 4'b0)) | 
                     (~mask_counter[0] & ~mask_counter[1] & ~mask_counter[2] & mask_counter[3] & (digit3 == 4'b0));

  wire [1:0] mod0 = digit0 % 3;
  wire [1:0] mod1 = digit1 % 3;
  wire [1:0] mod2 = digit2 % 3;
  wire [1:0] mod3 = digit3 % 3;
  wire [3:0] sum_mod = (mask_counter[0] ? mod0 : 0) + (mask_counter[1] ? mod1 : 0) + (mask_counter[2] ? mod2 : 0) + (mask_counter[3] ? mod3 : 0);
  wire valid = ~leading_zero & ((sum_mod == 0) | (sum_mod == 3) | (sum_mod == 6));

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      mask_counter <= 0;
      count_reg <= 0;
      cycle_counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            mask_counter <= 1;
            count_reg <= 0;
            cycle_counter <= 0;
            state <= PROCESSING;
          end
        end

        PROCESSING: begin
          done <= 0;
          cycle_counter <= cycle_counter + 1;

          if (mask_counter <= max_mask && cycle_counter < 20) begin
            if (valid) begin
              if (count_reg + 1 >= 32'h3B9ACA07)
                count_reg <= count_reg + 1 - 32'h3B9ACA07;
              else
                count_reg <= count_reg + 1;
            end
            mask_counter <= mask_counter + 1;
          end

          if (cycle_counter == 20) begin
            result <= count_reg;
            done <= 1;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule