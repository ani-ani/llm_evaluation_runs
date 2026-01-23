module torpedo_dodger (
  input clk,
  input rst_n,
  input start,
  input [5:0] ship_x1 [0:7],
  input [5:0] ship_x2 [0:7],
  input [5:0] ship_y [0:7],
  input [3:0] num_ships,
  output reg [15:0] path_data,
  output reg done,
  output reg possible
);

  // Parameters
  localparam N = 16;
  localparam IDLE = 3'b000;
  localparam BUILD_RANGES = 3'b001;
  localparam CHECK_POSSIBLE = 3'b010;
  localparam TRACE_PATH = 3'b011;
  localparam COMPLETE = 3'b100;

  // State register
  reg [2:0] state = IDLE;

  // Range storage (L and R for each step)
  reg [5:0] L [0:N];
  reg [5:0] R [0:N];

  // Path reconstruction
  reg [5:0] current_x;
  reg [15:0] path_reg;

  // Counters
  reg [7:0] step_counter;
  reg [7:0] trace_counter;
  reg [7:0] cycle_counter;

  // Ship processing
  reg [5:0] ship_L;
  reg [5:0] ship_R;
  reg ship_active;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      possible <= 0;
      path_data <= 0;
      step_counter <= 0;
      trace_counter <= 0;
      cycle_counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= BUILD_RANGES;
            cycle_counter <= 0;
            step_counter <= 0;
            L[0] <= 0;
            R[0] <= 0;
          end
        end

        BUILD_RANGES: begin
          if (cycle_counter == 255) begin
            state <= CHECK_POSSIBLE;
          end else if (step_counter < N) begin
            // Calculate new range
            L[step_counter+1] <= (step_counter+1 == 1) ? (L[step_counter] - 1) : (L[step_counter] - 1);
            R[step_counter+1] <= (step_counter+1 == 1) ? (R[step_counter] + 1) : (R[step_counter] + 1);

            // Clamp to [-N, N]
            if (L[step_counter+1] < -N) L[step_counter+1] <= -N;
            if (R[step_counter+1] > N) R[step_counter+1] <= N;

            // Check for ships at current y
            ship_active = 0;
            for (int i = 0; i < num_ships; i = i + 1) begin
              if (ship_y[i] == step_counter+1) begin
                ship_L = ship_x1[i];
                ship_R = ship_x2[i];
                ship_active = 1;
              end
            end

            if (ship_active) begin
              // Intersect with ship complement
              if (L[step_counter+1] < ship_L) begin
                if (R[step_counter+1] < ship_L) begin
                  // No intersection with ship
                end else if (R[step_counter+1] < ship_R) begin
                  R[step_counter+1] <= ship_L - 1;
                end else begin
                  // Split range
                  if (L[step_counter+1] < ship_L && R[step_counter+1] > ship_R) begin
                    // Two segments possible, we take the left one
                    R[step_counter+1] <= ship_L - 1;
                  end
                end
              end else if (L[step_counter+1] < ship_R) begin
                if (R[step_counter+1] < ship_R) begin
                  // Entirely within ship
                  L[step_counter+1] <= ship_R + 1;
                  R[step_counter+1] <= ship_R;
                end else begin
                  L[step_counter+1] <= ship_R + 1;
                end
              end
            end

            step_counter <= step_counter + 1;
          end
          cycle_counter <= cycle_counter + 1;
        end

        CHECK_POSSIBLE: begin
          possible <= (L[N] <= R[N]);
          if (possible) begin
            state <= TRACE_PATH;
            trace_counter <= N-1;
            current_x <= 0;
            path_reg <= 0;
          end else begin
            state <= COMPLETE;
            done <= 1;
          end
        end

        TRACE_PATH: begin
          if (trace_counter == 0) begin
            state <= COMPLETE;
            done <= 1;
            path_data <= path_reg;
          end else begin
            // Find valid predecessor
            reg [5:0] prev_x;
            reg [1:0] move;

            // Try straight first
            if (current_x >= L[trace_counter] && current_x <= R[trace_counter]) begin
              prev_x = current_x;
              move = 0;
            end
            // Then try left
            else if (current_x-1 >= L[trace_counter] && current_x-1 <= R[trace_counter]) begin
              prev_x = current_x - 1;
              move = 1;
            end
            // Then try right
            else if (current_x+1 >= L[trace_counter] && current_x+1 <= R[trace_counter]) begin
              prev_x = current_x + 1;
              move = 1;
            end
            else begin
              // Shouldn't happen if possible is high
              prev_x = current_x;
              move = 0;
            end

            current_x <= prev_x;
            path_reg <= {move, path_reg[15:1]};
            trace_counter <= trace_counter - 1;
          end
        end

        COMPLETE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule