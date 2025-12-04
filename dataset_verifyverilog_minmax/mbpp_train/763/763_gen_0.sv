module min_diff_finder (
  input clk,
  input rst_n,
  input start,
  input [7:0] element_count,
  input [7:0][7:0] array_in,
  output reg [7:0] min_diff,
  output reg done
);

  // Internal signals and registers
  reg [7:0] arr [0:7];
  reg [7:0] ecnt;
  reg [7:0] i;
  reg [7:0] j;
  reg [7:0] j_next;
  reg [7:0] diff;
  reg start_r;
  wire start_pos;
  reg [2:0] state;

  localparam IDLE      = 3'b000;
  localparam INIT      = 3'b001;
  localparam COMPARE   = 3'b010;
  localparam SWAP      = 3'b011;
  localparam POST_SWAP = 3'b100;
  localparam FIND_MIN  = 3'b101;
  localparam DONE      = 3'b110;

  // Edge detection on start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_r <= 1'b0;
    else start_r <= start;
  end
  assign start_pos = start && !start_r;

  // State machine and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      done    <= 1'b0;
      min_diff <= 8'b0;
      i       <= 8'b0;
      j       <= 8'b0;
      j_next  <= 8'b0;
      diff    <= 8'b0;
      ecnt    <= 8'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start_pos) begin
            ecnt <= (element_count > 8) ? 8'd8 : element_count;
            state <= INIT;
          end
        end

        INIT: begin
          // Load only the valid portion of the array; others are don't-care
          arr[0] <= array_in[0];
          arr[1] <= array_in[1];
          arr[2] <= array_in[2];
          arr[3] <= array_in[3];
          arr[4] <= array_in[4];
          arr[5] <= array_in[5];
          arr[6] <= array_in[6];
          arr[7] <= array_in[7];
          i      <= 8'b0;
          j      <= 8'b0;
          j_next <= 8'b0;
          diff   <= 8'b0;
          if (ecnt < 2) begin
            min_diff <= 8'b0;
            done     <= 1'b1;
            state    <= IDLE;
          end else begin
            min_diff <= 8'hFF; // reset for min search
            state    <= COMPARE;
          end
        end

        COMPARE: begin
          // Bubble sort compare adjacent elements
          j       <= j;
          j_next  <= j + 1;
          if ((j + 1) < ecnt) begin
            diff <= (arr[j_next] > arr[j]) ? (arr[j_next] - arr[j]) : (arr[j] - arr[j_next]);
            if (arr[j_next] < arr[j]) begin
              state <= SWAP;
            end else begin
              state <= POST_SWAP;
            end
          end else begin
            // End of inner loop
            if (i + 1 < ecnt - 1) begin
              i    <= i + 1;
              j    <= 8'b0;
              state <= COMPARE;
            end else begin
              state <= FIND_MIN;
            end
          end
        end

        SWAP: begin
          // Swap arr[j] and arr[j_next]
          arr[j]       <= arr[j_next];
          arr[j_next]  <= arr[j];
          state <= POST_SWAP;
        end

        POST_SWAP: begin
          if ((j + 1) < ecnt - 1) begin
            j    <= j + 1;
            state <= COMPARE;
          end else begin
            if (i + 1 < ecnt - 1) begin
              i    <= i + 1;
              j    <= 8'b0;
              state <= COMPARE;
            end else begin
              state <= FIND_MIN;
            end
          end
        end

        FIND_MIN: begin
          // Compute min difference on sorted adjacent elements
          if ((i + 1) < ecnt) begin
            diff <= (arr[i+1] > arr[i]) ? (arr[i+1] - arr[i]) : (arr[i] - arr[i+1]);
            if (diff < min_diff) min_diff <= diff;
            i <= i + 1;
          end else begin
            done <= 1'b1;
            state <= IDLE;
          end
        end

        DONE: begin
          // Fallback state (not strictly used here)
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
