module unique_sorted (
  input clk,
  input rst_n,
  input [7:0] d_in[7:0],
  input start,
  output reg [7:0] result[7:0],
  output reg [3:0] count,
  output reg done
);

  parameter IDLE = 3'b000;
  parameter LOAD = 3'b001;
  parameter SORT = 3'b010;
  parameter DEDUP = 3'b011;
  parameter DONE = 3'b100;

  reg [7:0] array_reg [7:0];
  reg [7:0] unique_reg [7:0];
  reg [3:0] state;
  reg [6:0] sort_counter;
  reg [3:0] dedup_counter;
  reg [3:0] unique_count;
  reg [7:0] last_unique;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      sort_counter <= 7'b0;
      dedup_counter <= 4'b0;
      unique_count <= 4'b0;
      for (int i=0; i<8; i++) begin
        array_reg[i] <= 8'b0;
        unique_reg[i] <= 8'b0;
      end
      result <= '{default:8'b0};
      count <= 4'b0;
      last_unique <= 8'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          sort_counter <= 7'b0;
          dedup_counter <= 4'b0;
          unique_count <= 4'b0;
          last_unique <= 8'b0;
          if (start) begin
            state <= LOAD;
          end
        end
        LOAD: begin
          for (int i=0; i<8; i++) begin
            array_reg[i] <= d_in[i];
          end
          unique_count <= 4'b0;
          last_unique <= 8'b0;
          sort_counter <= 7'b0;
          state <= SORT;
        end
        SORT: begin
          int i;
          i = sort_counter % 8;
          if (i < 7) begin
            if (array_reg[i] > array_reg[i+1]) begin
              array_reg[i] <= array_reg[i+1];
              array_reg[i+1] <= array_reg[i];
            end
          end
          sort_counter <= sort_counter + 1;
          if (sort_counter == 63) begin
            state <= DEDUP;
            dedup_counter <= 4'b0;
          end
        end
        DEDUP: begin
          if (dedup_counter == 0) begin
            unique_reg[0] <= array_reg[0];
            unique_count <= 4'b1;
            last_unique <= array_reg[0];
          end else begin
            if (array_reg[dedup_counter] == last_unique) begin
              // do nothing
            end else begin
              unique_reg[unique_count] <= array_reg[dedup_counter];
              unique_count <= unique_count + 1;
              last_unique <= array_reg[dedup_counter];
            end
          end
          dedup_counter <= dedup_counter + 1;
          if (dedup_counter == 7) begin
            state <= DONE;
            done <= 1'b1;
            result <= unique_reg;
            count <= unique_count;
          end
        end
        DONE: begin
          done <= 1'b1;
          if (start) begin
            state <= LOAD;
            done <= 1'b0;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule