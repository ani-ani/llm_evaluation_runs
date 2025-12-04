module name_length_sum (
  input clk,
  input rst_n,
  input start,
  input [7:0] name1 [0:7],
  input [7:0] name2 [0:7],
  input [7:0] name3 [0:7],
  input [7:0] name4 [0:7],
  output reg [5:0] total_length,
  output reg done
);

  reg [1:0] cnt;
  reg running;
  reg [5:0] add_len;
  reg [5:0] len;
  integer i;
  reg is_upper;

  // Compute length and uppercase validity for the currently selected name
  always @(*) begin
    is_upper = 1'b0;
    len = 6'd0;
    case (cnt)
      2'd0: begin
        is_upper = (name1[0] >= 8'd65) && (name1[0] <= 8'd90);
        for (i = 0; i < 8; i = i + 1) begin
          if (name1[i] == 8'd0) break;
          len = len + 1;
        end
      end
      2'd1: begin
        is_upper = (name2[0] >= 8'd65) && (name2[0] <= 8'd90);
        for (i = 0; i < 8; i = i + 1) begin
          if (name2[i] == 8'd0) break;
          len = len + 1;
        end
      end
      2'd2: begin
        is_upper = (name3[0] >= 8'd65) && (name3[0] <= 8'd90);
        for (i = 0; i < 8; i = i + 1) begin
          if (name3[i] == 8'd0) break;
          len = len + 1;
        end
      end
      2'd3: begin
        is_upper = (name4[0] >= 8'd65) && (name4[0] <= 8'd90);
        for (i = 0; i < 8; i = i + 1) begin
          if (name4[i] == 8'd0) break;
          len = len + 1;
        end
      end
      default: begin
        is_upper = 1'b0;
        len = 6'd0;
      end
    endcase
    add_len = is_upper ? len : 6'd0;
  end

  // Sequential control and accumulation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      total_length <= 6'd0;
      done <= 1'b0;
      running <= 1'b0;
      cnt <= 2'd0;
    end else begin
      if (!running) begin
        // Idle: wait for start
        total_length <= 6'd0;
        done <= 1'b0;
        cnt <= 2'd0;
        if (start) begin
          running <= 1'b1;
        end else begin
          running <= 1'b0;
        end
      end else begin
        // Running: process 4 names, one per clock
        total_length <= total_length + add_len;
        if (cnt == 2'd3) begin
          // Last name processed in this cycle
          running <= 1'b0;
          done <= 1'b1;
          cnt <= 2'd0;
        end else begin
          done <= 1'b0;
          cnt <= cnt + 1;
        end
      end
    end
  end

endmodule
