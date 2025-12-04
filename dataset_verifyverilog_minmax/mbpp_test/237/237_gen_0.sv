module tuple_counter (
  input clk,
  input rst_n,
  input start,
  input [7:0] tuples [0:7][1:0],
  input [3:0] tuple_count,
  output reg [7:0] unique_tuples [0:7][1:0],
  output reg [3:0] counts [0:7],
  output reg [3:0] unique_count,
  output reg done
);

  parameter IDLE = 2'd0;
  parameter SORT = 2'd1;
  parameter UPDATE = 2'd2;
  parameter DONE = 2'd3;

  reg [1:0] state;
  reg [3:0] i;
  reg [7:0] current_tuple [1:0];
  reg found;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      unique_count <= 4'd0;
      for (int i0 = 0; i0 < 8; i0++) begin
        unique_tuples[i0] <= 8'b0;
        counts[i0] <= 4'd0;
      end
      i <= 4'd0;
      found <= 1'b0;
      current_tuple[0] <= 8'b0;
      current_tuple[1] <= 8'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            i <= 4'd0;
            unique_count <= 4'd0;
            if (tuple_count == 4'd0) begin
              done <= 1'b1;
              state <= DONE;
            end else begin
              state <= SORT;
            end
          end
        end
        SORT: begin
          if (tuples[i][0] > tuples[i][1]) begin
            current_tuple[0] <= tuples[i][1];
            current_tuple[1] <= tuples[i][0];
          end else begin
            current_tuple[0] <= tuples[i][0];
            current_tuple[1] <= tuples[i][1];
          end
          state <= UPDATE;
        end
        UPDATE: begin
          found <= 1'b0;
          for (int j0 = 0; j0 < 8; j0++) begin
            if (j0 < unique_count) begin
              if (current_tuple[0] == unique_tuples[j0][0] && current_tuple[1] == unique_tuples[j0][1]) begin
                counts[j0] <= counts[j0] + 1;
                found <= 1'b1;
              end
            end
          end
          if (!found && unique_count < 4'd8) begin
            unique_tuples[unique_count][0] <= current_tuple[0];
            unique_tuples[unique_count][1] <= current_tuple[1];
            counts[unique_count] <= 4'd1;
            unique_count <= unique_count + 1;
          end
          i <= i + 1;
          if (i == (tuple_count - 1)) begin
            done <= 1'b1;
            state <= DONE;
          end else begin
            state <= SORT;
          end
        end
        DONE: begin
          done <= 1'b1;
          if (!start) begin
            done <= 1'b0;
            state <= IDLE;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule