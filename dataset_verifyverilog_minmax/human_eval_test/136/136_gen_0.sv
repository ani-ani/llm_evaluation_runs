module min_max_finder (
  input clk,
  input rst_n,
  input start,
  input signed [7:0][7:0] data_in, // 8x8-bit signed integers (-128 to 127)
  output reg signed [7:0] a,       // largest negative (None = 8'd128)
  output reg signed [7:0] b,       // smallest positive (None = 8'd127)
  output reg done                  // high when results valid
);

  localparam NONE_A = 8'sd128; // sentinel for 'no negative found'
  localparam NONE_B = 8'sd127; // sentinel for 'no positive found'
  localparam CNT_W = 4;        // enough to count 0..7

  reg [CNT_W-1:0] idx;
  reg prev_start;
  wire start_pulse;
  reg processing;

  assign start_pulse = start && !prev_start;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a <= NONE_A;
      b <= NONE_B;
      done <= 1'b0;
      idx <= '0;
      prev_start <= 1'b0;
      processing <= 1'b0;
    end else begin
      prev_start <= start;

      if (start_pulse) begin
        // Initialize for a new computation
        a <= NONE_A;
        b <= NONE_B;
        done <= 1'b0;
        idx <= '0;
        processing <= 1'b1;
      end else if (processing) begin
        // Process one element per cycle
        case (idx)
          4'd0: begin
            if (data_in[0] < 8'sd0 && data_in[0] > a) a <= data_in[0];
            if (data_in[0] > 8'sd0 && data_in[0] < b) b <= data_in[0];
          end
          4'd1: begin
            if (data_in[1] < 8'sd0 && data_in[1] > a) a <= data_in[1];
            if (data_in[1] > 8'sd0 && data_in[1] < b) b <= data_in[1];
          end
          4'd2: begin
            if (data_in[2] < 8'sd0 && data_in[2] > a) a <= data_in[2];
            if (data_in[2] > 8'sd0 && data_in[2] < b) b <= data_in[2];
          end
          4'd3: begin
            if (data_in[3] < 8'sd0 && data_in[3] > a) a <= data_in[3];
            if (data_in[3] > 8'sd0 && data_in[3] < b) b <= data_in[3];
          end
          4'd4: begin
            if (data_in[4] < 8'sd0 && data_in[4] > a) a <= data_in[4];
            if (data_in[4] > 8'sd0 && data_in[4] < b) b <= data_in[4];
          end
          4'd5: begin
            if (data_in[5] < 8'sd0 && data_in[5] > a) a <= data_in[5];
            if (data_in[5] > 8'sd0 && data_in[5] < b) b <= data_in[5];
          end
          4'd6: begin
            if (data_in[6] < 8'sd0 && data_in[6] > a) a <= data_in[6];
            if (data_in[6] > 8'sd0 && data_in[6] < b) b <= data_in[6];
          end
          4'd7: begin
            if (data_in[7] < 8'sd0 && data_in[7] > a) a <= data_in[7];
            if (data_in[7] > 8'sd0 && data_in[7] < b) b <= data_in[7];
          end
          default: ;
        endcase

        if (idx == 4'd7) begin
          // Finished processing all 8 elements
          done <= 1'b1;
          processing <= 1'b0;
        end else begin
          idx <= idx + 1'b1;
        end
      end
      // else: hold results and 'done' until next start pulse
    end
  end

endmodule
