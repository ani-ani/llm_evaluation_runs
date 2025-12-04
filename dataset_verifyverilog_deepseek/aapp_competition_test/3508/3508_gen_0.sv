module pillar_collapse(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] b [0:7],
  output reg [3:0] max_damage,
  output reg [3:0] pillar_idx,
  output reg done
);

  reg [2:0] state;
  reg [3:0] i, j;
  reg [3:0] damage_count;
  reg [7:0] exist_mask;
  reg [15:0] pressure;
  reg [15:0] area_x2;

  // State definitions
  localparam IDLE   = 3'd0;
  localparam INIT   = 3'd1;
  localparam COMPUTE = 3'd2;
  localparam FINISH_I = 3'd3;
  localparam DONE   = 3'd4;

  // Combinatorial next state logic
  always @(*) begin
    case(state)
      IDLE: begin
        if (start) state = INIT;
        else state = IDLE;
      end
      INIT: begin
        state = COMPUTE;
      end
      COMPUTE: begin
        if (j == n) state = FINISH_I;
        else state = COMPUTE;
      end
      FINISH_I: begin
        if (i == n) state = DONE;
        else state = INIT;
      end
      DONE: state = DONE;
      default: state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 4'd0;
      j <= 4'd0;
      damage_count <= 4'd0;
      exist_mask <= 8'd0;
      max_damage <= 4'd0;
      pillar_idx <= 4'd0;
      done <= 1'b0;
    end else begin
      case(state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            max_damage <= 4'd0;
            pillar_idx <= 4'd0;
          end
        end
        INIT: begin
          j <= 4'd0;
          damage_count <= 4'd0;
          exist_mask <= ((1 << n) -1) & ~(1 << i);
        end
        COMPUTE: begin
          if (j != i) begin
            // Find left neighbor
            reg [3:0] left = 4'd8;
            for (int k=j-1; k>=0; k=k-1) begin
              if (exist_mask[k] && k < n) begin
                left = k;
                break;
              end
            end
            // Find right neighbor
            reg [3:0] right = 4'd8;
            for (int k=j+1; k<n; k=k+1) begin
              if (exist_mask[k] && k < n) begin
                right = k;
                break;
              end
            end
            // Calculate area and pressure
            if (left < 8 && right < 8)
              area_x2 = right - left;
            else if (left >= 8 && right < 8)
              area_x2 = j + right;
            else if (right >= 8 && left < 8)
              area_x2 = (n-1)*2 - left - j;
            else
              area_x2 = (n-1)*2;
            pressure = area_x2 * 16'd500;
            if (pressure > b[j]) damage_count <= damage_count + 1;
          end
          j <= j + 1;
        end
        FINISH_I: begin
          if (damage_count + 1 > max_damage) begin
            max_damage <= damage_count + 1;
            pillar_idx <= i;
          end
          i <= i + 1;
        end
        DONE: done <= 1'b1;
      endcase
    end
  end

  // Manage i reset
  always @(posedge clk) begin
    if (state == DONE || !rst_n) i <= 0;
  end

endmodule