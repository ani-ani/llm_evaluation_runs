module prod_signs (
   input clk,
   input rst_n, // active-low reset
   input start,
   input [2:0] arr_len,
   input [7:0] signed arr_data_0,
   input [7:0] signed arr_data_1,
   input [7:0] signed arr_data_2,
   input [7:0] signed arr_data_3,
   input [7:0] signed arr_data_4,
   input [7:0] signed arr_data_5,
   input [7:0] signed arr_data_6,
   input [7:0] signed arr_data_7,
   output reg [31:0] result,
   output reg valid
);

reg [31:0] sum;
reg [1:0] product_sign;
reg [1:0] state; // IDLE=0, CALCULATE=1, DONE=2
reg [2:0] proc_cnt; // processing counter (8 cycles)
reg [1:0] delay_cnt; // delay counter in DONE (2 cycles)
wire [2:0] current_index;
wire [7:0] signed current_data;

always @(*) begin
   current_index = 7 - proc_cnt;
   current_data = case(current_index)
      3'd0: arr_data_0;
      3'd1: arr_data_1;
      3'd2: arr_data_2;
      3'd3: arr_data_3;
      3'd4: arr_data_4;
      3'd5: arr_data_5;
      3'd6: arr_data_6;
      3'd7: arr_data_7;
      default: 8'd0;
   endcase
end

always @(posedge clk) begin
   if (!rst_n) begin
      sum <= 32'd0;
      product_sign <= 2'd1;
      state <= 2'd0;
      proc_cnt <= 3'd0;
      delay_cnt <= 2'd0;
      valid <= 1'b0;
      result <= 32'd0;
   end else begin
      if (state == 2'd0) begin // IDLE
          if (start == 1'b1) begin
              sum <= 32'd0;
              product_sign <= 2'd1;
              proc_cnt <= 3'd7; // Start processing count
              delay_cnt <= 2'd0;
              state <= 2'd1; // Move to CALCULATE
          end
      end else if (state == 2'd1) begin // CALCULATE
          // Update proc_cnt
          proc_cnt <= proc_cnt - 1;
          // Check if processing is done
          if (proc_cnt == 3'd0) begin
              state <= 2'd2; // Move to DONE
              delay_cnt <= 2'd1; // Initialize delay counter
              valid <= 1'b0; // Ensure valid is not set yet
          end
          // Process current element if applicable
          if (current_index < arr_len) begin
              if (current_data == 8'd0) begin
                  product_sign <= 2'd0;
              end else begin
                  if (product_sign == 2'd0) begin // already zero, no change
                  end else begin
                      if (current_data < 0) begin
                          if (product_sign == 2'd1) begin
                              product_sign <= 2'd2;
                          end else begin
                              product_sign <= 2'd1;
                          end
                      end // else positive, no change
                  end
              end
              // Update sum with absolute value
              sum <= sum + (current_data < 0 ? -current_data : current_data);
          end // end if current_index < arr_len
      end else if (state == 2'd2) begin // DONE
          if (delay_cnt == 2'd0) begin
              // Compute result
              if (product_sign == 2'd0) begin
                  result <= 32'd0;
              end else begin
                  if (product_sign == 2'd1) begin
                      result <= sum;
                  end else begin
                      result <= -sum;
                  end
              end
              valid <= 1'b1;
          end else begin
              if (delay_cnt > 0) begin
                  delay_cnt <= delay_cnt - 1;
              end
              // valid remains unchanged
          end
      end // endstate
   end // else not reset
end // always @(posedge clk)

endmodule