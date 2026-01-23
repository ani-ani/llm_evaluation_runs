module photo_scheduler (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [15:0] t,
  input [7:0] photo_idx,
  input [15:0] a_i,
  input [15:0] b_i,
  input load,
  output reg result,
  output reg done
);

  // Internal states
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    SORT,
    PROCESS,
    DONE
  } state_t;

  state_t state;
  reg [7:0] photo_count;
  reg [7:0] sort_pass;
  reg [7:0] sort_idx;
  reg [7:0] process_idx;
  reg [15:0] current_end;

  // Photo buffer: 8 entries of {a, b}
  reg [15:0] photo_a [0:7];
  reg [15:0] photo_b [0:7];

  // Temporary registers for sorting
  reg [15:0] temp_a;
  reg [15:0] temp_b;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      photo_count <= 0;
      sort_pass <= 0;
      sort_idx <= 0;
      process_idx <= 0;
      current_end <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            photo_count <= 0;
          end
        end

        LOAD: begin
          if (load && photo_idx < 8) begin
            photo_a[photo_idx] <= a_i;
            photo_b[photo_idx] <= b_i;
            if (photo_idx == n - 1) begin
              state <= SORT;
              photo_count <= n;
              sort_pass <= 0;
              sort_idx <= 0;
            end
          end
        end

        SORT: begin
          if (sort_pass < photo_count - 1) begin
            if (sort_idx < photo_count - sort_pass - 1) begin
              if (photo_b[sort_idx] > photo_b[sort_idx + 1]) begin
                // Swap
                temp_a <= photo_a[sort_idx];
                temp_b <= photo_b[sort_idx];
                photo_a[sort_idx] <= photo_a[sort_idx + 1];
                photo_b[sort_idx] <= photo_b[sort_idx + 1];
                photo_a[sort_idx + 1] <= temp_a;
                photo_b[sort_idx + 1] <= temp_b;
              end
              sort_idx <= sort_idx + 1;
            end else begin
              sort_idx <= 0;
              sort_pass <= sort_pass + 1;
            end
          end else begin
            state <= PROCESS;
            process_idx <= 0;
            current_end <= 0;
            result <= 1;
          end
        end

        PROCESS: begin
          if (process_idx < photo_count) begin
            if (current_end > photo_b[process_idx]) begin
              result <= 0;
            end
            current_end <= (current_end > photo_a[process_idx]) ? current_end + t : photo_a[process_idx] + t;
            process_idx <= process_idx + 1;
          end else begin
            state <= DONE;
            done <= 1;
          end
        end

        DONE: begin
          if (start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule