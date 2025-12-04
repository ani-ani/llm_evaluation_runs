module ip_zero_remover (
  input clk,
  input rst_n,
  input start,
  input [95:0] ip_bytes,
  output reg [95:0] clean_bytes,
  output reg done
);

  reg [4:0] cycle_cnt;
  reg [95:0] ip_reg;
  reg [23:0] clean_segments [0:3];

  function [23:0] process_segment(input [23:0] seg);
    reg [7:0] byte0, byte1, byte2;
    reg [7:0] b0, b1, b2;
    begin
      byte0 = seg[23:16];
      byte1 = seg[15:8];
      byte2 = seg[7:0];

      if (byte0 != 8'h30) begin
        b0 = byte0;
        b1 = byte1;
        b2 = byte2;
      end else if (byte1 != 8'h30) begin
        b0 = byte1;
        b1 = byte2;
        b2 = 8'h00;
      end else if (byte2 != 8'h30) begin
        b0 = byte2;
        b1 = 8'h00;
        b2 = 8'h00;
      end else begin
        b0 = 8'h30;
        b1 = 8'h00;
        b2 = 8'h00;
      end
      process_segment = {b0, b1, b2};
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt <= 5'd0;
      done <= 1'b0;
      clean_bytes <= 96'd0;
      ip_reg <= 96'd0;
      clean_segments[0] <= 24'd0;
      clean_segments[1] <= 24'd0;
      clean_segments[2] <= 24'd0;
      clean_segments[3] <= 24'd0;
    end else begin
      done <= 1'b0;

      if (start) begin
        ip_reg <= ip_bytes;
        cycle_cnt <= 5'd0;
      end else if (cycle_cnt < 5'd16) begin
        cycle_cnt <= cycle_cnt + 5'd1;
      end

      case (cycle_cnt)
        5'd0: clean_segments[0] <= process_segment(ip_reg[95:72]);
        5'd4: clean_segments[1] <= process_segment(ip_reg[71:48]);
        5'd8: clean_segments[2] <= process_segment(ip_reg[47:24]);
        5'd12: clean_segments[3] <= process_segment(ip_reg[23:0]);
        default: ;
      endcase

      if (cycle_cnt == 5'd15) begin
        clean_bytes <= {clean_segments[0], clean_segments[1], clean_segments[2], clean_segments[3]};
        done <= 1'b1;
      end
    end
  end

endmodule