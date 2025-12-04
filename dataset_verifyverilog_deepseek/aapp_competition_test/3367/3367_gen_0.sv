module monstermind_score_calculator (
  input clk,
  input rst_n,
  input start,
  input [3:0] t,
  input [1:0] n,
  input [4:0] wcnt0,
  input [4:0] wcnt1,
  input [4:0] wcnt2,
  input [4:0] wcnt3,
  output reg [31:0] expected_score,
  output reg done
);
  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE_STATE = 2'b10;
  reg [1:0] state, next_state;
  reg [3:0] stored_t;
  reg [1:0] stored_n;
  reg [4:0] stored_wcnt [0:3];
  reg [3:0] current_s;
  reg [31:0] max_value;
  reg [3:0] best_s;
  wire active_0, active_1, active_2, active_3;
  wire unique_0, unique_1, unique_2, unique_3;
  wire [2:0] count_unique;
  wire [31:0] reciprocal_n;
  wire [63:0] score_product;
  wire [31:0] score;
  wire [31:0] value;
  
  assign active_0 = (0 < stored_n) && (stored_wcnt[0] <= current_s);
  assign active_1 = (1 < stored_n) && (stored_wcnt[1] <= current_s);
  assign active_2 = (2 < stored_n) && (stored_wcnt[2] <= current_s);
  assign active_3 = (3 < stored_n) && (stored_wcnt[3] <= current_s);
  
  wire match_0_1 = active_0 && active_1 && (stored_wcnt[0] == stored_wcnt[1]);
  wire match_0_2 = active_0 && active_2 && (stored_wcnt[0] == stored_wcnt[2]);
  wire match_0_3 = active_0 && active_3 && (stored_wcnt[0] == stored_wcnt[3]);
  assign unique_0 = active_0 && !(match_0_1 || match_0_2 || match_0_3);
  
  wire match_1_0 = active_1 && active_0 && (stored_wcnt[1] == stored_wcnt[0]);
  wire match_1_2 = active_1 && active_2 && (stored_wcnt[1] == stored_wcnt[2]);
  wire match_1_3 = active_1 && active_3 && (stored_wcnt[1] == stored_wcnt[3]);
  assign unique_1 = active_1 && !(match_1_0 || match_1_2 || match_1_3);
  
  wire match_2_0 = active_2 && active_0 && (stored_wcnt[2] == stored_wcnt[0]);
  wire match_2_1 = active_2 && active_1 && (stored_wcnt[2] == stored_wcnt[1]);
  wire match_2_3 = active_2 && active_3 && (stored_wcnt[2] == stored_wcnt[3]);
  assign unique_2 = active_2 && !(match_2_0 || match_2_1 || match_2_3);
  
  wire match_3_0 = active_3 && active_0 && (stored_wcnt[3] == stored_wcnt[0]);
  wire match_3_1 = active_3 && active_1 && (stored_wcnt[3] == stored_wcnt[1]);
  wire match_3_2 = active_3 && active_2 && (stored_wcnt[3] == stored_wcnt[2]);
  assign unique_3 = active_3 && !(match_3_0 || match_3_1 || match_3_2);
  
  assign count_unique = unique_0 + unique_1 + unique_2 + unique_3;
  
  assign reciprocal_n = (stored_n == 2'd1) ? 32'h00010000 :
                       (stored_n == 2'd2) ? 32'h00008000 :
                       (stored_n == 2'd3) ? 32'h00005555 : 32'h00004000;
  
  assign score_product = {count_unique, 16'b0} * reciprocal_n;
  assign score = score_product[63:32];
  
  wire [3:0] tmp = stored_t - current_s;
  assign value = score * tmp;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      expected_score <= 32'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            stored_t <= t;
            stored_n <= n;
            stored_wcnt[0] <= wcnt0;
            stored_wcnt[1] <= wcnt1;
            stored_wcnt[2] <= wcnt2;
            stored_wcnt[3] <= wcnt3;
            current_s <= 4'd1;
            max_value <= 32'b0;
            best_s <= 4'd0;
            state <= PROCESSING;
          end
        end
        PROCESSING: begin
          if (value > max_value) begin
            max_value <= value;
            best_s <= current_s;
          end
          if (current_s == stored_t) begin
            expected_score <= max_value;
            done <= 1'b1;
            state <= DONE_STATE;
          end else begin
            current_s <= current_s + 4'd1;
          end
        end
        DONE_STATE: begin
          done <= 1'b0;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule