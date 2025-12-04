module laser_reflection_calculator(
  input [31:0] x1, y1, x2, y2,
  input [31:0] px, py,
  output reg valid_hit,
  output reg inf_low, inf_high,
  output reg [31:0] y_low, y_high
);

  reg signed [63:0] denominator, a_ext, b_ext;
  wire signed [31:0] a = y2 - y1;
  wire signed [31:0] b = x1 - x2;
  wire signed [31:0] dx = x2 - x1;
  wire signed [31:0] dy = y2 - y1;
  wire signed [63:0] c = (dx * $signed(y1)) - (dy * $signed(x1));
  wire signed [63:0] ax = $signed(a) * $signed(px);
  wire signed [63:0] by = $signed(b) * $signed(py);
  wire signed [63:0] num_s2x = (ax + by + c) << 1;
  wire den_zero = (denominator == 64'sd0);
  
  reg signed [31:0] rx, ry;
  reg [31:0] y_hit [0:1];
  reg valid_y [0:1];
  reg inf_flag [0:1];

  always @* begin
    // Initialize defaults
    valid_hit = 1'b0;
    inf_low = 1'b0;
    inf_high = 1'b0;
    y_low = 32'sd0;
    y_high = 32'sd0;
    
    // Compute denominator
    a_ext = {{32{a[31]}}, a};
    b_ext = {{32{b[31]}}, b};
    denominator = (a_ext * a_ext) + (b_ext * b_ext);
    
    // Handle degenerate case
    if (den_zero) begin
      valid_hit = 1'b0;
    end else begin
      // Calculate reflected point
      rx = px - ( (num_s2x * a_ext) / denominator );
      ry = py - ( (num_s2x * b_ext) / denominator );
      
      // Process endpoints
      for (int i=0; i<2; i=i+1) begin
        reg signed [31:0] mx = (i==0) ? x1 : x2;
        reg signed [31:0] my = (i==0) ? y1 : y2;
        reg signed [31:0] dmx = mx - rx;
        reg signed [31:0] dmy = my - ry;
        
        valid_y[i] = 1'b0;
        inf_flag[i] = 1'b0;
        y_hit[i] = 32'sd0;
        
        if (dmx == 0) begin
          if (rx == 0) begin
            inf_flag[i] = 1'b1;
            valid_y[i] = 1'b1;
          end
        end else begin
          reg signed [63:0] t_num = -$signed(rx);
          reg signed [63:0] t_den = dmx;
          reg signed [63:0] t = (t_num * 64'sh10000) / t_den; // Fixed-div (Q16.16)
          if (t > 0) begin
            reg signed [63:0] ty = (t * dmy) >> 16;
            y_hit[i] = ry + ty[31:0];
            valid_y[i] = 1'b1;
          end
        end
      end
      
      // Check valid hits and determine output
      valid_hit = inf_flag[0] || inf_flag[1] || valid_y[0] || valid_y[1];
      inf_low = inf_flag[0] || inf_flag[1];
      inf_high = inf_flag[0] || inf_flag[1];
      
      // Find finite bounds
      if (valid_y[0] && valid_y[1]) begin
        y_low = (y_hit[0] < y_hit[1]) ? y_hit[0] : y_hit[1];
        y_high = (y_hit[0] > y_hit[1]) ? y_hit[0] : y_hit[1];
        inf_low = 1'b0;
        inf_high = 1'b0;
      end else if (valid_y[0]) begin
        y_low = y_hit[0];
        y_high = y_hit[0];
      end else if (valid_y[1]) begin
        y_low = y_hit[1];
        y_high = y_hit[1];
      end else begin
        if (!inf_low) valid_hit = 1'b0;
      end
    end
  end
endmodule