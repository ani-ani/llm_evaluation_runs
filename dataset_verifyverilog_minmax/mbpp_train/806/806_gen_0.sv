module max_uppercase_run (
  input clk,
  input rst_n,
  input start,
  input [127:0] str,
  output reg [3:0] max_run,
  output reg done
);

  reg [3:0] cycle_count;
  reg [3:0] current_run;

  always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      cycle_count <= 4'd0;
      current_run <= 4'd0;
      max_run <= 4'd0;
    end else begin
      if (done) begin
        if (start) begin
          done <= 1'b0;
          cycle_count <= 4'd0;
          current_run <= 4'd0;
          max_run <= 4'd0;
        end
        // else remain in done state
      end else begin
        // Processing state
        reg [3:0] next_current_run;
        reg [3:0] next_max_run;
        
        // Check if current character is uppercase (ASCII 65-90)
        if (str[(cycle_count*8) +: 8] >= 8'd65 && str[(cycle_count*8) +: 8] <= 8'd90) begin
          next_current_run = current_run + 1;
        end else begin
          next_current_run = 4'd0;
        end
        
        // Update max_run
        next_max_run = (max_run > next_current_run) ? max_run : next_current_run;
        
        // Update registers
        current_run <= next_current_run;
        max_run <= next_max_run;
        
        // Update cycle_count and done signal
        if (cycle_count == 4'd15) begin
          cycle_count <= 4'd0;
          done <= 1'b1;
        end else begin
          cycle_count <= cycle_count + 1;
          done <= 1'b0;
        end
      end
    end
  end

endmodule