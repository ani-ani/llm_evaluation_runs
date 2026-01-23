module steward_support (
  input clk,
  input rst_n,
  input start,
  input [7:0] strength,
  input [2:0] n,
  output reg [2:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    INPUT,
    CALCULATE,
    DONE
  } state_t;

  state_t state;
  reg [7:0] mem [0:7];
  reg [7:0] min_val;
  reg [7:0] max_val;
  reg [2:0] count;
  reg [2:0] idx;
  reg [2:0] calc_idx;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 3'b0;
      done <= 1'b0;
      idx <= 3'b0;
      calc_idx <= 3'b0;
      min_val <= 8'hFF;
      max_val <= 8'h00;
      count <= 3'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INPUT;
            idx <= 3'b0;
            min_val <= 8'hFF;
            max_val <= 8'h00;
            count <= 3'b0;
            done <= 1'b0;
          end
        end
        INPUT: begin
          if (idx < n) begin
            mem[idx] <= strength;
            if (idx == 0) begin
              min_val <= strength;
              max_val <= strength;
            end else begin
              if (strength < min_val) min_val <= strength;
              if (strength > max_val) max_val <= strength;
            end
            idx <= idx + 1'b1;
          end else begin
            state <= CALCULATE;
            calc_idx <= 3'b0;
          end
        end
        CALCULATE: begin
          if (calc_idx < n) begin
            if (mem[calc_idx] > min_val && mem[calc_idx] < max_val) begin
              count <= count + 1'b1;
            end
            calc_idx <= calc_idx + 1'b1;
          end else begin
            state <= DONE;
            result <= count;
            done <= 1'b1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end

endmodule