module consecutive_subsequence_cost(
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [7:0] element_0,
  input [7:0] element_1,
  input [7:0] element_2,
  input [7:0] element_3,
  input [7:0] element_4,
  input [7:0] element_5,
  input [7:0] element_6,
  input [7:0] element_7,
  output reg [29:0] result,
  output reg done
);

  localparam MOD = 30'd1_000_000_000;

  typedef enum logic [1:0] {
    IDLE  = 2'd0,
    COMP  = 2'd1, // COMPUTE_MIN_MAX
    ACC   = 2'd2, // ACCUMULATE
    DONE  = 2'd3  // FINISH
  } state_t;

  state_t state;

  reg [2:0] curr_start;
  reg [2:0] curr_end;
  reg [7:0] curr_min;
  reg [7:0] curr_max;
  reg [29:0] accum;
  reg [2:0] n_r;

  function [7:0] get_elem(input [2:0] idx);
    case (idx)
      3'd0: get_elem = element_0;
      3'd1: get_elem = element_1;
      3'd2: get_elem = element_2;
      3'd3: get_elem = element_3;
      3'd4: get_elem = element_4;
      3'd5: get_elem = element_5;
      3'd6: get_elem = element_6;
      3'd7: get_elem = element_7;
      default: get_elem = 8'd0;
    endcase
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 30'd0;
      accum <= 30'd0;
      n_r <= 3'd0;
      curr_start <= 3'd0;
      curr_end <= 3'd0;
      curr_min <= 8'd0;
      curr_max <= 8'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          result <= 30'd0;
          accum <= 30'd0;
          if (start) begin
            n_r <= N;
            curr_start <= 3'd0;
            curr_end <= 3'd0;
            state <= COMP;
          end else begin
            state <= IDLE;
          end
        end

        COMP: begin
          // Single inner-iteration per clock: expand subsequence [curr_start..curr_end]
          if (curr_end < n_r) begin
            if (curr_start == curr_end) begin
              curr_min <= get_elem(curr_end);
              curr_max <= get_elem(curr_end);
            end else begin
              if (get_elem(curr_end) < curr_min) curr_min <= get_elem(curr_end);
              if (get_elem(curr_end) > curr_max) curr_max <= get_elem(curr_end);
            end
            curr_end <= curr_end + 1;
            state <= COMP;
          end else begin
            // Full subsequence processed; go to ACCUMULATE for one cycle
            state <= ACC;
          end
        end

        ACC: begin
          // Compute and accumulate (min * max * len) % MOD
          begin
            integer len;
            len = (curr_end - curr_start + 1);
            accum <= (accum + ((curr_min * curr_max) * len)) % MOD;
          end
          // Prepare next subsequence or finish
          if (curr_start < (n_r - 1)) begin
            curr_start <= curr_start + 1;
            curr_end <= curr_start + 1;
            state <= COMP;
          end else begin
            state <= DONE;
          end
        end

        DONE: begin
          result <= accum;
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
          end else begin
            state <= DONE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
