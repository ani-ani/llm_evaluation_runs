module bookcase_area_min(
  input clk,
  input rst_n,
  input start,
  input [8:0] h0, h1, h2, h3, h4,
  input [4:0] t0, t1, t2, t3, t4,
  output reg [17:0] min_area,
  output reg done
);
  
  reg [7:0] cnt; // max 243 (8 bits)
  reg [8:0] sh0, sh1, sh2;
  reg [7:0] st0, st1, st2;
  reg [7:0] max_thick;
  reg [9:0] total_height;
  reg [17:0] current_area;
  
  reg [1:0] state;
  parameter IDLE = 2'd0, INIT = 2'd1, PROCESS = 2'd2, DONE_ST = 2'd3;
  
  wire [1:0] s0, s1, s2, s3, s4;
  wire valid;
  
  assign s0 = cnt % 3;
  assign s1 = (cnt / 3) % 3;
  assign s2 = (cnt / 9) % 3;
  assign s3 = (cnt / 27) % 3;
  assign s4 = (cnt / 81) % 3;
  
  assign valid = (s0 == 0 || s1 == 0 || s2 == 0 || s3 == 0 || s4 == 0) &&
                 (s0 == 1 || s1 == 1 || s2 == 1 || s3 == 1 || s4 == 1) &&
                 (s0 == 2 || s1 == 2 || s2 == 2 || s3 == 2 || s4 == 2);
  
  // Shelf 0 height calculation
  always @(*) begin
    sh0 = 0;
    if (s0 == 0) sh0 = h0;
    if (s1 == 0 && h1 > sh0) sh0 = h1;
    if (s2 == 0 && h2 > sh0) sh0 = h2;
    if (s3 == 0 && h3 > sh0) sh0 = h3;
    if (s4 == 0 && h4 > sh0) sh0 = h4;
  end
  
  // Shelf 1 height calculation
  always @(*) begin
    sh1 = 0;
    if (s0 == 1) sh1 = h0;
    if (s1 == 1 && h1 > sh1) sh1 = h1;
    if (s2 == 1 && h2 > sh1) sh1 = h2;
    if (s3 == 1 && h3 > sh1) sh1 = h3;
    if (s4 == 1 && h4 > sh1) sh1 = h4;
  end
  
  // Shelf 2 height calculation
  always @(*) begin
    sh2 = 0;
    if (s0 == 2) sh2 = h0;
    if (s1 == 2 && h1 > sh2) sh2 = h1;
    if (s2 == 2 && h2 > sh2) sh2 = h2;
    if (s3 == 2 && h3 > sh2) sh2 = h3;
    if (s4 == 2 && h4 > sh2) sh2 = h4;
  end
  
  // Shelf 0 thickness calculation
  always @(*) begin
    st0 = 0;
    if (s0 == 0) st0 = t0;
    if (s1 == 0) st0 = st0 + t1;
    if (s2 == 0) st0 = st0 + t2;
    if (s3 == 0) st0 = st0 + t3;
    if (s4 == 0) st0 = st0 + t4;
  end
  
  // Shelf 1 thickness calculation
  always @(*) begin
    st1 = 0;
    if (s0 == 1) st1 = t0;
    if (s1 == 1) st1 = st1 + t1;
    if (s2 == 1) st1 = st1 + t2;
    if (s3 == 1) st1 = st1 + t3;
    if (s4 == 1) st1 = st1 + t4;
  end
  
  // Shelf 2 thickness calculation
  always @(*) begin
    st2 = 0;
    if (s0 == 2) st2 = t0;
    if (s1 == 2) st2 = st2 + t1;
    if (s2 == 2) st2 = st2 + t2;
    if (s3 == 2) st2 = st2 + t3;
    if (s4 == 2) st2 = st2 + t4;
  end
  
  // Total height and max thickness
  always @(*) begin
    total_height = sh0 + sh1 + sh2;
    if (st0 >= st1 && st0 >= st2) max_thick = st0;
    else if (st1 >= st0 && st1 >= st2) max_thick = st1;
    else max_thick = st2;
    current_area = total_height * max_thick;
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      min_area <= 18'h3FFFF;
      done <= 0;
      cnt <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= INIT;
            min_area <= 18'h3FFFF;
          end
        end
        INIT: begin
          cnt <= 0;
          state <= PROCESS;
        end
        PROCESS: begin
          if (cnt < 243) begin
            if (valid && current_area < min_area)
              min_area <= current_area;
            cnt <= cnt + 1;
          end else begin
            state <= DONE_ST;
          end
        end
        DONE_ST: begin
          done <= 1;
          if (!start) state <= IDLE;
        end
      endcase
    end
  end
  
endmodule