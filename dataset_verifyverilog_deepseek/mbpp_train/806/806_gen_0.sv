module max_uppercase_run(input clk, input rst_n, input start, input [127:0] str, output reg [3:0] max_run, output reg done);
  reg [4:0] counter;
  reg [3:0] current_run;
  reg [3:0] max_run_reg;
  reg done_reg;
  wire [7:0] current_char = (counter < 16) ? str[8*counter +:8] : 8'h00;
  wire is_uppercase = (current_char >= 8'd65) && (current_char <= 8'd90);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done_reg <= 1'b1;
      counter <= 5'd0;
      current_run <= 4'd0;
      max_run_reg <= 4'd0;
      done <= 1'b1;
    end else begin
      if (done_reg) begin
        if (start) begin
          done_reg <= 1'b0;
          counter <= 5'd0;
          current_run <= 4'd0;
          max_run_reg <= 4'd0;
        end
      end else begin
        if (counter < 16) begin
          if (is_uppercase) begin
            current_run <= (current_run == 4'd15) ? current_run : current_run + 4'd1;
            if ((current_run == 4'd15) ? 4'd15 : (current_run + 4'd1)) > max_run_reg) begin
              max_run_reg <= (current_run == 4'd15) ? 4'd15 : (current_run + 4'd1);
            end
          end else begin
            current_run <= 4'd0;
          end
        end
        counter <= counter + 5'd1;
      end
      
      if (counter == 5'd16) begin
        done_reg <= 1'b1;
        max_run <= max_run_reg;
      end
      done <= done_reg;
    end
  end
endmodule