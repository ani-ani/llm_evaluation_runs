module string_sublist_sorter #(
  parameter MAX_SUBLIST_SIZE = 4,
  parameter MAX_LIST_SIZE    = 4,
  parameter STR_WIDTH        = 8
) (
  input clk,
  input rst_n,
  input start,
  input [MAX_LIST_SIZE-1:0][MAX_SUBLIST_SIZE-1:0][STR_WIDTH-1:0] data_in,
  input [7:0] sizes_in [MAX_LIST_SIZE-1:0],
  output reg [MAX_LIST_SIZE-1:0][MAX_SUBLIST_SIZE-1:0][STR_WIDTH-1:0] data_out,
  output reg done
);

  // State machine encoding
  localparam ST_IDLE      = 2'b00;
  localparam ST_PREP      = 2'b01;
  localparam ST_PRE_WAIT  = 2'b10;
  localparam ST_SORT      = 2'b11;

  // Internal registers
  reg [1:0] state, next_state;
  reg [7:0] sublist_idx;   // Current sublist index [0..MAX_LIST_SIZE-1]
  reg [7:0] next_idx;
  reg [7:0] curr_size;     // Size of current sublist (1..MAX_SUBLIST_SIZE)
  reg [7:0] no_ops;        // Pre-compare idle cycles needed to hit exactly N^2 cycles per sublist
  reg [7:0] k_reg;         // Current k (number of valid elements) in current sublist
  reg [$clog2(MAX_SUBLIST_SIZE+1):0] i_reg; // Bubble sort outer index
  reg [$clog2(MAX_SUBLIST_SIZE+1):0] j_reg; // Bubble sort inner index
  reg [7:0] total_cycles;  // Cycles used in current sublist (includes pre-compare idle cycles)
  reg [7:0] ops_done;      // Completed compare-swaps in current sublist

  // Working copy of data
  reg [STR_WIDTH-1:0] mem [0:MAX_SUBLIST_SIZE-1];

  // Helper function to find first set bit in a mask up to 4 bits
  function [1:0] ffs4;
    input [3:0] mask;
    integer k;
    begin
      ffs4 = 0;
      for (k = 0; k < 4; k = k + 1) begin
        if (mask[k]) begin
          ffs4 = k[1:0];
          break;
        end
      end
    end
  endfunction

  // Sequential logic (clocked, async reset)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= ST_IDLE;
      sublist_idx <= 8'd0;
      curr_size   <= 8'd0;
      no_ops      <= 8'd0;
      k_reg       <= 8'd0;
      i_reg       <= 8'd0;
      j_reg       <= 8'd0;
      total_cycles<= 8'd0;
      ops_done    <= 8'd0;
      done        <= 1'b0;
      data_out    <= '0;
      mem[0]      <= '0;
      mem[1]      <= '0;
      mem[2]      <= '0;
      mem[3]      <= '0;
    end else begin
      // Defaults
      done <= 1'b0;

      case (state)
        ST_IDLE: begin
          sublist_idx <= 8'd0;
          i_reg       <= 8'd0;
          j_reg       <= 8'd0;
          total_cycles<= 8'd0;
          ops_done    <= 8'd0;
          if (start) begin
            // Load current sublist size (validated by prep state)
            curr_size   <= sizes_in[0];
            // Load data for sublist 0 into working memory
            mem[0] <= data_in[0][0];
            mem[1] <= data_in[0][1];
            mem[2] <= data_in[0][2];
            mem[3] <= data_in[0][3];
            state <= ST_PREP;
          end else begin
            state <= ST_IDLE;
          end
        end

        ST_PREP: begin
          // Determine actual k (number of valid elements) with safety cap
          k_reg <= (curr_size >= 1 && curr_size <= MAX_SUBLIST_SIZE) ? curr_size : 8'd0;
          i_reg <= 8'd0;
          j_reg <= 8'd0;
          ops_done <= 8'd0;
          if (k_reg <= 1) begin
            // For k<=1, sorting is trivial; still need k^2 cycles total per spec
            no_ops <= k_reg * k_reg; // 1 or 0 no-ops
            total_cycles <= 8'd0;
            state <= ST_PRE_WAIT;
          end else begin
            // Pre-compare idle cycles so total cycles = k^2
            // Pre-compare idle cycles = k*(k-1)/2
            no_ops <= (k_reg * (k_reg - 1)) >> 1;
            total_cycles <= 8'd0;
            state <= ST_PRE_WAIT;
          end
        end

        ST_PRE_WAIT: begin
          // Waste cycles to pad to k^2 total cycles for this sublist
          total_cycles <= total_cycles + 1;
          if (total_cycles + 1 >= no_ops) begin
            // Start actual compare-swaps with i=1, j=0 for (N*(N-1)/2) valid steps
            i_reg <= 1;
            j_reg <= 0;
            state <= ST_SORT;
          end else begin
            state <= ST_PRE_WAIT;
          end
        end

        ST_SORT: begin
          if (k_reg <= 1) begin
            // No swaps needed; immediately finalize sublist
            total_cycles <= total_cycles + 1;
            // Write back result for this sublist
            data_out[sublist_idx][0] <= mem[0];
            data_out[sublist_idx][1] <= mem[1];
            data_out[sublist_idx][2] <= mem[2];
            data_out[sublist_idx][3] <= mem[3];

            if (sublist_idx == (MAX_LIST_SIZE - 1)) begin
              done  <= 1'b1;
              state <= ST_IDLE;
            end else begin
              // Prepare next sublist
              sublist_idx <= sublist_idx + 1;
              curr_size   <= sizes_in[sublist_idx + 1];
              mem[0] <= data_in[sublist_idx + 1][0];
              mem[1] <= data_in[sublist_idx + 1][1];
              mem[2] <= data_in[sublist_idx + 1][2];
              mem[3] <= data_in[sublist_idx + 1][3];
              state <= ST_PREP;
            end
          end else begin
            // Perform one compare-swap (bubble sort) per cycle
            if (mem[j_reg] > mem[j_reg + 1]) begin
              // Swap adjacent elements
              mem[j_reg]     <= mem[j_reg + 1];
              mem[j_reg + 1] <= mem[j_reg];
            end
            ops_done   <= ops_done + 1;
            total_cycles <= total_cycles + 1;

            // Advance j; if j+1 == i, advance i and reset j
            if (j_reg + 1 == i_reg) begin
              i_reg <= i_reg + 1;
              j_reg <= 0;
            end else begin
              j_reg <= j_reg + 1;
            end

            // Check if compare-swap phase is complete
            if (ops_done + 1 >= ((k_reg * (k_reg - 1)) >> 1)) begin
              // Write back result for this sublist
              data_out[sublist_idx][0] <= mem[0];
              data_out[sublist_idx][1] <= mem[1];
              data_out[sublist_idx][2] <= mem[2];
              data_out[sublist_idx][3] <= mem[3];

              if (sublist_idx == (MAX_LIST_SIZE - 1)) begin
                done  <= 1'b1;
                state <= ST_IDLE;
              end else begin
                // Prepare next sublist
                sublist_idx <= sublist_idx + 1;
                curr_size   <= sizes_in[sublist_idx + 1];
                mem[0] <= data_in[sublist_idx + 1][0];
                mem[1] <= data_in[sublist_idx + 1][1];
                mem[2] <= data_in[sublist_idx + 1][2];
                mem[3] <= data_in[sublist_idx + 1][3];
                state <= ST_PREP;
              end
            end else begin
              state <= ST_SORT;
            end
          end
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule