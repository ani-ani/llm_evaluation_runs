module weather_prediction (
   input clk,
   input rst_n, // active low reset
   input start,
   input signed [15:0] temp_in,
   input [6:0] n,
   output reg signed [15:0] prediction,
   output reg done,
   output reg valid
);

reg [2:0] state;
reg [6:0] n_value;
reg [15:0] last_temp, d;
reg is_ap;
reg [6:0] count;

always_ff @(posedge clk)
   if (!rst_n) begin
      state <= 3'd0; // IDLE
      n_value <= 0;
      count <=0;
      last_temp <=0;
      d <=0;
      is_ap <=1; // start as AP true
      prediction <=0;
      done <=0;
      valid <=0;
   end else begin
      if (state == 3'd0) begin // IDLE
          if (start) begin
             n_value <= n;
             state <= 3'd1; // LOAD
          end
      end else if (state == 3'd1) begin // LOAD
          if (count < n_value) begin
             if (count ==1) begin
                 d <= temp_in - last_temp;
             end
             last_temp <= temp_in;
             if (count >=2) begin
                 if (temp_in - last_temp != d) begin
                     is_ap <=0;
                 end
             end
             count <= count +1;
             state <= 3'd1; // stay in LOAD
          end else begin
             state <= 3'd2; // CHECK
          end
      end else if (state ==3'd2) begin // CHECK
          state <=3'd3; // COMPUTE
      end else if (state == 3'd3) begin // COMPUTE
          if (is_ap) begin
              prediction <= last_temp + d;
          end else begin
              prediction <= last_temp;
          end
          state <=3'd4; // DONE
      end else if (state ==3'd4) begin // DONE
          done <=1;
          valid <=1;
          state <=3'd4; // stay
      end
   end
endmodule