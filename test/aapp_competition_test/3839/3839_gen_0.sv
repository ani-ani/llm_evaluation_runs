module knight_placement_generator(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [7:0] x,
  output reg [7:0] y,
  output reg valid,
  output reg done
);

  // Internal registers
  reg [3:0] idx;          // current knight index (0..n-1)
  reg [3:0] limit;        // threshold = (n / 3) * 2
  reg [1:0] state;        // FSM state

  localparam IDLE    = 2'd0;
  localparam COMPUTE = 2'd1;
  localparam GAP     = 2'd2;
  localparam FINISH  = 2'd3;

  // Compute limit when start is seen in IDLE
  wire [3:0] div_n3  = n / 3;          // integer division
  wire [4:0] limit_w = {1'b0,div_n3} << 1; // (n/3)*2, fits within 5 bits

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x     <= 8'sd0;
      y     <= 8'sd0;
      valid <= 1'b0;
      done  <= 1'b0;
      idx   <= 4'd0;
      limit <= 4'd0;
      state <= IDLE;
    end else begin
      // Defaults each cycle
      valid <= 1'b0;
      done  <= 1'b0;

      case (state)
        IDLE: begin
          idx <= 4'd0;
          if (start && (n != 4'd0)) begin
            // Precompute limit = (n/3)*2, saturate to 4 bits (n is max 16 so safe)
            limit <= limit_w[3:0];
            state <= COMPUTE;
          end
        end

        COMPUTE: begin
          // Generate coordinate for current idx
          if (idx < limit) begin
            if (idx[0] == 1'b0) begin
              x <= {4'd0, idx};   // even: x = i
              y <= 8'sd0;         // y = 0
            end else begin
              x <= {4'd0, (idx - 4'd1)}; // odd: x = i-1
              y <= 8'sd3;                // y = 3
            end
          end else begin
            x <= {4'd0, idx};     // else: x = i
            y <= 8'sd0;           // y = 0
          end

          valid <= 1'b1;          // assert valid for this cycle

          // Move to GAP or FINISH
          if (idx == (n - 1)) begin
            state <= FINISH;      // last valid just issued
          end else begin
            idx   <= idx + 4'd1;
            state <= GAP;
          end
        end

        GAP: begin
          // One-cycle gap with valid deasserted
          // Next cycle we output next coordinate
          state <= COMPUTE;
        end

        FINISH: begin
          // One cycle after last valid
          done  <= 1'b1;
          state <= IDLE;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule