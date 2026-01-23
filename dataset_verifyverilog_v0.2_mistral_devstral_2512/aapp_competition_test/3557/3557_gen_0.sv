module train_chaos (
  input clk,
  input rst_n,
  input start,
  input [2:0] p_in,
  input [2:0] idx_in,
  output reg [15:0] max_chaos,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD_PASSENGERS,
    LOAD_ORDER,
    BLOW_UP,
    CALC_CHAOS,
    UPDATE_MAX,
    DONE
  } state_t;

  state_t state;
  reg [2:0] p [0:7];
  reg [2:0] order [0:7];
  reg [2:0] blow_idx;
  reg [2:0] current_idx;
  reg [2:0] segment_start;
  reg [2:0] segment_end;
  reg [15:0] current_chaos;
  reg [15:0] segment_sum;
  reg [2:0] segment_count;
  reg [2:0] i;
  reg [2:0] j;
  reg [2:0] k;
  reg [2:0] temp;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_chaos <= 0;
      done <= 0;
      blow_idx <= 0;
      current_idx <= 0;
      segment_start <= 0;
      segment_end <= 0;
      current_chaos <= 0;
      segment_sum <= 0;
      segment_count <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      temp <= 0;
      for (int idx = 0; idx < 8; idx++) begin
        p[idx] <= 0;
        order[idx] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_PASSENGERS;
            current_idx <= 0;
          end
        end

        LOAD_PASSENGERS: begin
          p[current_idx] <= p_in;
          current_idx <= current_idx + 1;
          if (current_idx == 7) begin
            state <= LOAD_ORDER;
            current_idx <= 0;
          end
        end

        LOAD_ORDER: begin
          order[current_idx] <= idx_in;
          current_idx <= current_idx + 1;
          if (current_idx == 7) begin
            state <= BLOW_UP;
            blow_idx <= 0;
            current_chaos <= 0;
            segment_count <= 0;
            segment_sum <= 0;
          end
        end

        BLOW_UP: begin
          // Mark coach as destroyed
          temp <= order[blow_idx] - 1;
          p[temp] <= 0;
          state <= CALC_CHAOS;
        end

        CALC_CHAOS: begin
          // Calculate segments and chaos
          segment_count <= 0;
          current_chaos <= 0;
          segment_sum <= 0;
          i <= 0;
          j <= 0;
          state <= UPDATE_MAX;
        end

        UPDATE_MAX: begin
          // Iterate through coaches to find segments
          if (i < 8) begin
            if (p[i] != 0) begin
              segment_sum <= p[i];
              j <= i + 1;
              while (j < 8 && p[j] != 0) begin
                segment_sum <= segment_sum + p[j];
                j <= j + 1;
              end
              if (segment_sum > 0) begin
                current_chaos <= current_chaos + 10;
                segment_count <= segment_count + 1;
              end
              i <= j;
            end else begin
              i <= i + 1;
            end
          end else begin
            // Multiply by number of segments
            current_chaos <= current_chaos * segment_count;
            if (current_chaos > max_chaos) begin
              max_chaos <= current_chaos;
            end
            blow_idx <= blow_idx + 1;
            if (blow_idx == 7) begin
              state <= DONE;
              done <= 1;
            end else begin
              state <= BLOW_UP;
            end
          end
        end

        DONE: begin
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