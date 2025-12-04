module group_trip_solver(
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [2:0] preferences [0:7],
  output reg [3:0] max_count,
  output reg done
);

  // State encodings
  typedef enum {
    IDLE    = 3'd0,
    ITERATE = 3'd1,
    CHECK   = 3'd2,
    COMPARE = 3'd3,
    DONE    = 3'd4
  } states_t;

  reg [2:0] state;
  reg [8:0] cycle_counter;
  reg [7:0] mask;
  reg [3:0] curr_size;
  reg is_valid;
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_count <= 0;
      done <= 0;
      cycle_counter <= 0;
      mask <= 0;
    end else begin
      case (state)
        IDLE: begin
          max_count <= 0;
          done <= 0;
          cycle_counter <= 0;
          if (start) begin
            state <= ITERATE;
            mask <= 8'd0;
          end
        end

        ITERATE: begin
          mask <= mask + 1;
          state <= CHECK;
        end

        CHECK: begin
          // Calculate subset size
          curr_size = 0;
          for (i = 0; i < 8; i++)
            curr_size += mask[i];

          // Check dependency constraints
          is_valid = 1;
          for (i = 0; i < 8; i++) begin
            if (mask[i] && !mask[preferences[i]]) begin
              is_valid = 0;
            end
          end
          state <= COMPARE;
        end

        COMPARE: begin
          if (is_valid && (curr_size <= k) && (curr_size > max_count))
            max_count <= curr_size;

          cycle_counter <= cycle_counter + 1;
          if (cycle_counter == 255) state <= DONE;
          else state <= ITERATE;
        end

        DONE: begin
          done <= 1;
          if (cycle_counter == 259) state <= IDLE;
          else cycle_counter <= cycle_counter + 1;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule