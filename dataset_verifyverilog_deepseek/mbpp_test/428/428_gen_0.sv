module shell_sort (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] data_in,
  output reg [7:0][7:0] data_out,
  output reg done
);

  localparam [2:0]
    IDLE      = 3'd0,
    LOAD      = 3'd1,
    GAP_CALC  = 3'd2,
    COMPARE   = 3'd3,
    SWAP      = 3'd4,
    UPDATE_GAP= 3'd5,
    DONE      = 3'd6;

  reg [2:0] state;
  reg [7:0][7:0] array_reg;
  reg [2:0] gap;
  reg [3:0] idx;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      array_reg <= '0;
      gap       <= 3'b0;
      idx       <= 4'b0;
      data_out  <= '0;
      done      <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) state <= LOAD;
        end

        LOAD: begin
          array_reg <= data_in;
          gap       <= 3'b100; // Initial gap = 4
          state     <= GAP_CALC;
        end

        GAP_CALC: begin
          idx   <= gap;
          state <= COMPARE;
        end

        COMPARE: begin
          if (idx < 8) begin
            if (array_reg[idx - gap] > array_reg[idx]) begin
              state <= SWAP;
            end else begin
              idx   <= idx + 1;
              state <= COMPARE;
            end
          end else begin
            state <= UPDATE_GAP;
          end
        end

        SWAP: begin
          array_reg[idx - gap] <= array_reg[idx];
          array_reg[idx]       <= array_reg[idx - gap];
          idx                  <= idx + 1;
          state                <= COMPARE;
        end

        UPDATE_GAP: begin
          gap <= gap >> 1;
          if (gap == 3'b0) begin
            state <= DONE;
          end else begin
            state <= GAP_CALC;
          end
        end

        DONE: begin
          data_out <= array_reg;
          done     <= 1'b1;
          state    <= IDLE;
        end
      endcase
    end
  end
endmodule