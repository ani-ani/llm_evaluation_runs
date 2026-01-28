module equal_tuples_check #(
  parameter NUM_TUPLES = 4,
  parameter MAX_TUPLE_LEN = 8
) (
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire [3:0] tuple_len_0,
  input wire [3:0] tuple_len_1,
  input wire [3:0] tuple_len_2,
  input wire [3:0] tuple_len_3,
  input wire [3:0] tuple_len_4,
  input wire [3:0] tuple_len_5,
  input wire [3:0] tuple_len_6,
  input wire [3:0] tuple_len_7,
  input wire [3:0] num_tuples,
  output reg result,
  output reg done
);

  localparam [2:0] IDLE = 3'd0;
  localparam [2:0] LOAD_REF = 3'd1;
  localparam [2:0] COMPARE = 3'd2;
  localparam [2:0] FINISHED = 3'd3;

  reg [2:0] state;
  reg [3:0] reference_len;
  reg [3:0] compare_idx;
  reg [3:0] current_len;
  reg comparison_failed;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 1'b0;
      done <= 1'b0;
      reference_len <= 4'd0;
      compare_idx <= 4'd0;
      current_len <= 4'd0;
      comparison_failed <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          comparison_failed <= 1'b0;
          if (start) begin
            if (num_tuples == 4'd0 || num_tuples == 4'd1) begin
              result <= 1'b1;
              state <= FINISHED;
            end else begin
              compare_idx <= 4'd0;
              state <= LOAD_REF;
            end
          end
        end

        LOAD_REF: begin
          case (compare_idx)
            4'd0: reference_len <= tuple_len_0;
            4'd1: reference_len <= tuple_len_1;
            4'd2: reference_len <= tuple_len_2;
            4'd3: reference_len <= tuple_len_3;
            4'd4: reference_len <= tuple_len_4;
            4'd5: reference_len <= tuple_len_5;
            4'd6: reference_len <= tuple_len_6;
            4'd7: reference_len <= tuple_len_7;
            default: reference_len <= tuple_len_0;
          endcase
          compare_idx <= 4'd1;
          result <= 1'b1;
          state <= COMPARE;
        end

        COMPARE: begin
          if (compare_idx < num_tuples) begin
            case (compare_idx)
              4'd0: current_len <= tuple_len_0;
              4'd1: current_len <= tuple_len_1;
              4'd2: current_len <= tuple_len_2;
              4'd3: current_len <= tuple_len_3;
              4'd4: current_len <= tuple_len_4;
              4'd5: current_len <= tuple_len_5;
              4'd6: current_len <= tuple_len_6;
              4'd7: current_len <= tuple_len_7;
              default: current_len <= 4'd0;
            endcase
            
            if (current_len != reference_len) begin
              result <= 1'b0;
              comparison_failed <= 1'b1;
              state <= FINISHED;
            end else begin
              if (compare_idx >= num_tuples - 1) begin
                state <= FINISHED;
              end else begin
                compare_idx <= compare_idx + 1;
              end
            end
          end else begin
            state <= FINISHED;
          end
        end

        FINISHED: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule