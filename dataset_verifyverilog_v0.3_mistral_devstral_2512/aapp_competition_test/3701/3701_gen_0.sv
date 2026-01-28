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

  reg [1:0] state, next_state;
  reg [4:0] idx;          // 0-16 counter
  reg [3:0] groups;       // Zero group count (max 16)
  reg prev_bit;           // Previous bit (1 at start)
  reg [31:0] min_val;     // min(x,y)
  reg [3:0] add_count;    // Addition counter
  reg [39:0] accumulator; // Sum accumulator
  reg [39:0] result_reg;  // Registered result
  reg done_reg;

  // State transition
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
      state <= next_state;
      done_reg <= (state == FINISH);
      if (state == COMPUTE && add_count == 4'd0)
        result_reg <= accumulator + y;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = TRAVERSE;
      TRAVERSE: if (idx == 5'd16) next_state = (groups == 4'd0) ? FINISH : COMPUTE;
      COMPUTE: if (add_count == 4'd0) next_state = FINISH;
      FINISH: if (!start) next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx <= 5'd0;
      groups <= 4'd0;
      prev_bit <= 1'b1;
      min_val <= 32'd0;
      add_count <= 4'd0;
      accumulator <= 40'd0;
    end else begin
      case (state)
        IDLE: begin
          idx <= 5'd0;
          groups <= 4'd0;
          prev_bit <= 1'b1;
        end

        TRAVERSE: begin
          if (idx < 5'd16) begin
            // Count new zero group: current=0 and previous=1
            if (a[idx] == 1'b0 && prev_bit == 1'b1)
              groups <= groups + 4'd1;
            prev_bit <= a[idx];
            idx <= idx + 5'd1;
          end else if (groups > 4'd0) begin
            min_val <= (x < y) ? x : y;
            add_count <= groups - 4'd1;  // Number of additions needed
            accumulator <= 40'd0;
          end
        end

        COMPUTE: begin
          if (add_count > 4'd0) begin
            accumulator <= accumulator + min_val;
            add_count <= add_count - 4'd1;
          end
        end
      endcase
    end
  end

  // Output assignments
  assign result = result_reg;
  assign done = done_reg;
endmodule