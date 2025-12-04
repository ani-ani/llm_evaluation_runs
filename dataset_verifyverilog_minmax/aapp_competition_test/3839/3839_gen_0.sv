module knight_placement_generator (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [7:0] x,
  output reg [7:0] y,
  output reg valid,
  output reg done
);

  // State machine states
  localparam IDLE = 2'b00;
  localparam GEN  = 2'b01;
  localparam DONE = 2'b10;

  // State and control signals
  reg [1:0] state;
  reg [3:0] knight_counter;
  reg first_knight;

  // Compute coordinates from examples pattern
  function [7:0] compute_x;
    input [3:0] i;
    input [3:0] n;
    begin
      if (i < 4) begin
        case (i)
          0: compute_x = 0;
          1: compute_x = 1;
          2: compute_x = 1;
          3: compute_x = 2;
          default: compute_x = i;
        endcase
      end else begin
        if (i < (n/3)*2) begin
          if (i % 2 == 0)
            compute_x = i;
          else
            compute_x = i-1;
        end else begin
          compute_x = i;
        end
      end
    end
  endfunction

  function [7:0] compute_y;
    input [3:0] i;
    input [3:0] n;
    begin
      if (i < 4) begin
        case (i)
          0: compute_y = 0;
          1: compute_y = 0;
          2: compute_y = 3;
          3: compute_y = 0;
          default: compute_y = 0;
        endcase
      end else begin
        if (i < (n/3)*2) begin
          if (i % 2 == 0)
            compute_y = 0;
          else
            compute_y = 3;
        end else begin
          compute_y = 0;
        end
      end
    end
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      x <= 0;
      y <= 0;
      valid <= 0;
      done <= 0;
      knight_counter <= 0;
      first_knight <= 1;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= GEN;
            x <= compute_x(0, n);
            y <= compute_y(0, n);
            valid <= 1;
            done <= 0;
            knight_counter <= 1;
            first_knight <= 0;
          end else begin
            valid <= 0;
            done <= 0;
            knight_counter <= 0;
            first_knight <= 1;
          end
        end

        GEN: begin
          if (valid) begin
            // Currently outputting valid data
            valid <= 0;
          end else begin
            // Wait cycle
            if (knight_counter < n) begin
              x <= compute_x(knight_counter, n);
              y <= compute_y(knight_counter, n);
              valid <= 1;
              knight_counter <= knight_counter + 1;
            end else begin
              // Finished all knights
              state <= DONE;
              valid <= 0;
              done <= 1;
              knight_counter <= 0;
            end
          end
        end

        DONE: begin
          done <= 0;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule