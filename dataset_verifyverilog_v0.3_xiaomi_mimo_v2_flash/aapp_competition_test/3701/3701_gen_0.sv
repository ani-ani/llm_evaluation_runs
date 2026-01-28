module min_cost(
  input clk, rst_n, start,
  input [15:0] a,   // 16-bit binary string (a[0]=first char, a[15]=last char)
  input [31:0] x, y, // Operation costs
  output reg [39:0] result,
  output reg done
);
  // States
  localparam [1:0] IDLE = 2'd0;
  localparam [1:0] TRAVERSE = 2'd1;
  localparam [1:0] COMPUTE = 2'd2;
  localparam [1:0] FINISH = 2'd3;

  reg [1:0] state;
  reg [4:0] idx;          // 0-16 counter
  reg [3:0] groups;       // Zero group count (max 16)
  reg prev_bit;           // Previous bit (1 at start)
  reg [31:0] min_val;     // min(x,y)
  reg [3:0] add_count;    // Addition counter
  reg [39:0] accumulator; // Sum accumulator
  reg [39:0] result_reg;  // Registered result
  reg done_reg;

  // State transition and output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done_reg <= 1'b0;
      result_reg <= 40'd0;
      idx <= 5'd0;
      groups <= 4'd0;
      prev_bit <= 1'b1;
      min_val <= 32'd0;
      add_count <= 4'd0;
      accumulator <= 40'd0;
    end else begin
      case (state)
        IDLE: begin
          done_reg <= 1'b0;
          if (start) begin
            state <= TRAVERSE;
            idx <= 5'd0;
            groups <= 4'd0;
            prev_bit <= 1'b1;
          end
        end

        TRAVERSE: begin
          if (idx < 16) begin
            // Count new zero group: current=0 and previous=1
            if (a[idx] == 1'b0 && prev_bit == 1'b1)
              groups <= groups + 4'd1;
            prev_bit <= a[idx];
            idx <= idx + 5'd1;
          end else begin
            if (groups > 4'd0) begin
              min_val <= (x < y) ? x : y;
              add_count <= groups - 4'd1;  // Number of additions needed
              accumulator <= 40'd0;
              state <= COMPUTE;
            end else begin
              // No groups (all ones or empty)
              state <= FINISH;
              result_reg <= 40'd0;  // Cost is zero
            end
          end
        end

        COMPUTE: begin
          if (add_count > 4'd0) begin
            accumulator <= accumulator + {8'd0, min_val};
            add_count <= add_count - 4'd1;
          end else begin
            // All additions done
            state <= FINISH;
            result_reg <= accumulator + {8'd0, y};
          end
        end

        FINISH: begin
          done_reg <= 1'b1;
          result <= result_reg;
          if (!start) begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Continuous assignment for outputs
  always @(*) begin
    result = result_reg;
    done = done_reg;
  end
endmodule