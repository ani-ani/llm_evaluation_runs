module kth_element(
  input logic clk,
  input logic rst_n,
  input logic start,
  input logic [7:0] k,
  input logic [7:0][7:0] arr,
  output logic [7:0] result,
  output logic done
);

  // Internal memory for sorting
  logic [7:0] mem [0:7];
  logic [2:0] i_cnt, j_cnt;
  logic swapped;
  logic [2:0] state;
  logic [7:0] temp;

  // State encodings
  localparam IDLE        = 3'b000;
  localparam LOAD_DATA   = 3'b001;
  localparam OUTER_LOOP  = 3'b010;
  localparam COMPARE     = 3'b011;
  localparam DONE        = 3'b100;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      i_cnt      <= 3'b0;
      j_cnt      <= 3'b0;
      swapped    <= 1'b0;
      result     <= 8'b0;
      done       <= 1'b1;
      for (int idx = 0; idx < 8; idx++) mem[idx] <= 8'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b1;
          if (start) begin
            state     <= LOAD_DATA;
            done      <= 1'b0;
          end
        end

        LOAD_DATA: begin
          for (int idx = 0; idx < 8; idx++) mem[idx] <= arr[idx];
          i_cnt   <= 3'b0;
          j_cnt   <= 3'b0;
          swapped <= 1'b0;
          state   <= OUTER_LOOP;
        end

        OUTER_LOOP: begin
          if (i_cnt >= 3'd7) begin
            // All passes completed – output result
            result <= mem[k-1];
            state  <= DONE;
          end else begin
            // Begin a new pass
            swapped <= 1'b0;
            j_cnt   <= 3'b0;
            state   <= COMPARE;
          end
        end

        COMPARE: begin
          if (j_cnt >= 3'd7 - i_cnt) begin
            // End of this pass
            i_cnt <= i_cnt + 1'b1;
            if (!swapped) begin
              // Array is sorted – early exit
              result <= mem[k-1];
              state  <= DONE;
            end else begin
              state <= OUTER_LOOP;
            end
          end else begin
            // Compare and conditionally swap mem[j] and mem[j+1]
            if (mem[j_cnt] > mem[j_cnt+1]) begin
              temp = mem[j_cnt];
              mem[j_cnt]   <= mem[j_cnt+1];
              mem[j_cnt+1] <= temp;
              swapped <= 1'b1;
            end
            j_cnt <= j_cnt + 1'b1;
            // Remain in COMPARE for the next element
          end
        end

        DONE: begin
          done  <= 1'b1;   // result is valid for one cycle
          state <= IDLE;   // return to idle state
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
