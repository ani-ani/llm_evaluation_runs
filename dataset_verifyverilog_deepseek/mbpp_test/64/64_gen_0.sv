module sort_by_score (
  input clk,
  input start,
  input rst_n,
  input [3:0][7:0] scores,
  output [3:0][7:0] sorted_scores,
  output [3:0][1:0] sorted_indices,
  output reg done
);

  typedef enum logic [1:0] {IDLE, COMPARE, SWAP, DONE} state_t;
  state_t state;

  reg [3:0][7:0] current_scores;
  reg [3:0][1:0] current_indices;
  reg [1:0] pass_counter;
  reg [1:0] comp_counter;

  assign sorted_scores = current_scores;
  assign sorted_indices = current_indices;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_scores <= '0;
      current_indices <= '0;
      pass_counter <= '0;
      comp_counter <= '0;
      done <= 1'b0;
    end else begin
      case(state)
        IDLE: begin
          if (start) begin
            current_scores <= scores;
            current_indices <= {2'd0, 2'd1, 2'd2, 2'd3};
            pass_counter <= 2'd0;
            comp_counter <= 2'd0;
            done <= 1'b0;
            state <= COMPARE;
          end
        end

        COMPARE: begin
          if (current_scores[comp_counter] > current_scores[comp_counter + 1]) begin
            state <= SWAP;
          end else begin
            if (comp_counter == (3 - pass_counter - 1)) begin
              if (pass_counter == 2'd2) begin
                done <= 1'b1;
                state <= DONE;
              end else begin
                pass_counter <= pass_counter + 1;
                comp_counter <= 2'd0;
              end
            end else begin
              comp_counter <= comp_counter + 1;
            end
          end
        end

        SWAP: begin
          current_scores[comp_counter] <= current_scores[comp_counter + 1];
          current_scores[comp_counter + 1] <= current_scores[comp_counter];
          current_indices[comp_counter] <= current_indices[comp_counter + 1];
          current_indices[comp_counter + 1] <= current_indices[comp_counter];

          if (comp_counter == (3 - pass_counter - 1)) begin
            if (pass_counter == 2'd2) begin
              done <= 1'b1;
              state <= DONE;
            end else begin
              pass_counter <= pass_counter + 1;
              comp_counter <= 2'd0;
              state <= COMPARE;
            end
          end else begin
            comp_counter <= comp_counter + 1;
            state <= COMPARE;
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule