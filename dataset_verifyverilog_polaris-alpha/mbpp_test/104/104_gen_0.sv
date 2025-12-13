module string_sublist_sorter #(
  parameter int MAX_SUBLIST_SIZE = 4,
  parameter int MAX_LIST_SIZE    = 4,
  parameter int STR_WIDTH        = 8
)(
  input  logic                                             clk,
  input  logic                                             rst_n,
  input  logic                                             start,
  input  logic [MAX_LIST_SIZE-1:0][MAX_SUBLIST_SIZE-1:0][STR_WIDTH-1:0] data_in,
  input  logic [7:0]                                       sizes_in [MAX_LIST_SIZE-1:0],
  output logic [MAX_LIST_SIZE-1:0][MAX_SUBLIST_SIZE-1:0][STR_WIDTH-1:0] data_out,
  output logic                                             done
);

  // FSM states
  typedef enum logic [1:0] {
    S_IDLE   = 2'b00,
    S_SETUP  = 2'b01,
    S_SORT   = 2'b10,
    S_WRITE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Indices and control
  logic [$clog2(MAX_LIST_SIZE)   -1:0] sublist_idx;
  logic [$clog2(MAX_SUBLIST_SIZE)-1:0] i_cnt;
  logic [$clog2(MAX_SUBLIST_SIZE)-1:0] j_cnt;

  logic [7:0] current_size;

  // Local buffer for current sublist
  logic [MAX_SUBLIST_SIZE-1:0][STR_WIDTH-1:0] buf;

  // Sequential state/control and main operations
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      sublist_idx <= '0;
      i_cnt       <= '0;
      j_cnt       <= '0;
      current_size<= '0;
      buf         <= '0;
      data_out    <= '0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            sublist_idx <= '0;
          end
        end

        S_SETUP: begin
          // Load current sublist size (clamp between 1 and MAX_SUBLIST_SIZE)
          if (sizes_in[sublist_idx] < 8'd1)
            current_size <= 8'd1;
          else if (sizes_in[sublist_idx] > MAX_SUBLIST_SIZE[7:0])
            current_size <= MAX_SUBLIST_SIZE[7:0];
          else
            current_size <= sizes_in[sublist_idx];

          // Load entire sublist into local buffer
          buf <= data_in[sublist_idx];

          // Initialize bubble sort indices
          i_cnt <= '0;
          j_cnt <= '0;
        end

        S_SORT: begin
          // Perform one compare-swap per cycle if within current_size
          if (current_size > 8'd1) begin
            if (j_cnt + 1 < current_size[$bits(j_cnt)-1:0]) begin
              // Compare first ASCII character and swap if needed
              if (buf[j_cnt][7:0] > buf[j_cnt+1][7:0]) begin
                logic [STR_WIDTH-1:0] tmp;
                tmp            = buf[j_cnt];
                buf[j_cnt]     = buf[j_cnt+1];
                buf[j_cnt+1]   = tmp;
              end
              j_cnt <= j_cnt + 1'b1;
            end else begin
              j_cnt <= '0;
              if (i_cnt + 1 < current_size[$bits(i_cnt)-1:0]) begin
                i_cnt <= i_cnt + 1'b1;
              end
            end
          end
        end

        S_WRITE: begin
          // Write sorted buffer back to corresponding sublist in data_out
          data_out[sublist_idx] <= buf;

          // Move to next sublist or finish
          if (sublist_idx == MAX_LIST_SIZE-1) begin
            done <= 1'b1;
          end else begin
            sublist_idx <= sublist_idx + 1'b1;
          end
        end

        default: begin
          // Should not occur; safe defaults
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_SETUP;
      end

      S_SETUP: begin
        next_state = S_SORT;
      end

      S_SORT: begin
        if (current_size <= 8'd1) begin
          // Trivial or degenerate case
          next_state = S_WRITE;
        end else begin
          // Completed all passes when i_cnt reached last-1 and j_cnt at end
          if ((i_cnt + 1 >= current_size[$bits(i_cnt)-1:0]) &&
              (j_cnt + 1 >= current_size[$bits(j_cnt)-1:0])) begin
            next_state = S_WRITE;
          end else begin
            next_state = S_SORT;
          end
        end
      end

      S_WRITE: begin
        if (sublist_idx == MAX_LIST_SIZE-1) begin
          // All sublists processed; wait in IDLE for next start
          next_state = S_IDLE;
        end else begin
          // Proceed to next sublist
          next_state = S_SETUP;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule