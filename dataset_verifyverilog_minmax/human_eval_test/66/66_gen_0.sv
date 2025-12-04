module uppercase_sum(
  input clk,
  input rst_n,
  input start,
  input [127:0] s_string,
  output reg [10:0] sum,
  output reg done
);

  // Constants
  localparam BYTES = 16;
  localparam CNT_W = $clog2(BYTES + 1); // 5 bits to count 0..16

  // Internal signals
  reg processing;
  reg prev_start;
  reg [CNT_W-1:0] byte_idx;
  reg [7:0] byte;

  // Detect rising edge of start pulse
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prev_start <= 1'b0;
    end else begin
      prev_start <= start;
    end
  end

  // Main FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum        <= 11'h0;
      done       <= 1'b0;
      processing <= 1'b0;
      byte_idx   <= {CNT_W{1'b0}};
    end else begin
      if (!processing && prev_start && !start) begin
        // Start of new computation (one-cycle pulse)
        sum        <= 11'h0;
        done       <= 1'b0;
        processing <= 1'b1;
        byte_idx   <= {CNT_W{1'b0}};
      end else if (processing) begin
        // Process one byte per cycle
        case (byte_idx)
          5'd0:  byte <= s_string[  7:  0];
          5'd1:  byte <= s_string[ 15:  8];
          5'd2:  byte <= s_string[ 23: 16];
          5'd3:  byte <= s_string[ 31: 24];
          5'd4:  byte <= s_string[ 39: 32];
          5'd5:  byte <= s_string[ 47: 40];
          5'd6:  byte <= s_string[ 55: 48];
          5'd7:  byte <= s_string[ 63: 56];
          5'd8:  byte <= s_string[ 71: 64];
          5'd9:  byte <= s_string[ 79: 72];
          5'd10: byte <= s_string[ 87: 80];
          5'd11: byte <= s_string[ 95: 88];
          5'd12: byte <= s_string[103: 96];
          5'd13: byte <= s_string[111:104];
          5'd14: byte <= s_string[119:112];
          5'd15: byte <= s_string[127:120];
          default: byte <= 8'h0;
        endcase

        if ((byte >= 8'd65) && (byte <= 8'd90)) begin
          sum <= sum + 11'd1; // ASCII value of uppercase letter
        end

        if (byte_idx == (BYTES - 1)) begin
          // Last byte processed; hold sum and assert done
          processing <= 1'b0;
          done       <= 1'b1;
          byte_idx   <= {CNT_W{1'b0}};
        end else begin
          byte_idx <= byte_idx + 1;
        end
      end else begin
        // Idle (not processing)
        done       <= 1'b1; // Keep done asserted while waiting for next start
        processing <= 1'b0;
        byte_idx   <= {CNT_W{1'b0}};
      end
    end
  end

endmodule
