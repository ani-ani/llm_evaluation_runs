module top_n_finder (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [3:0]  n,
  input  logic [127:0] data,
  output logic [127:0] result,
  output logic        done
);

  // Internal states
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    LOAD  = 2'b01,
    PROC  = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Parsed data array: elem[0] is data[7:0], elem[15] is data[127:120]
  logic signed [7:0] elem [0:15];

  // Top N array and associated valid flags
  logic signed [7:0] top_val [0:15];
  logic        [15:0] top_valid;

  // Index for processing input elements (0-15)
  logic [4:0] idx;      // needs to count up to 16

  // Clamped N (in case n == 0, treat as 0; if >16, clamp to 16)
  logic [4:0] n_eff;

  // Combinational clamp for n
  always_comb begin
    if (n == 4'd0)
      n_eff = 5'd0;
    else if (n > 4'd16)
      n_eff = 5'd16;
    else
      n_eff = {1'b0, n};
  end

  // Parse input data into elem[] every cycle (purely combinational)
  genvar gi;
  generate
    for (gi = 0; gi < 16; gi++) begin : GEN_ELEM
      assign elem[gi] = data[8*gi +: 8];
    end
  endgenerate

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = (n_eff == 0) ? DONE : LOAD;
      end
      LOAD: begin
        // Initialize; move to processing first element
        next_state = PROC;
      end
      PROC: begin
        if (idx == 5'd16)
          next_state = DONE;
      end
      DONE: begin
        // Stay in DONE until start deasserted and asserted again
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential main logic
  integer i, j;
  logic signed [7:0] curr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx      <= 5'd0;
      done     <= 1'b0;
      result   <= 128'd0;
      top_valid <= 16'd0;
      for (i = 0; i < 16; i++) begin
        top_val[i] <= '0;
      end
    end else begin
      case (state)
        IDLE: begin
          done    <= 1'b0;
          result  <= 128'd0;
          idx     <= 5'd0;
          if (start && n_eff == 0) begin
            // No elements requested; directly done
            done <= 1'b1;
          end
        end

        LOAD: begin
          // Initialize top arrays
          done      <= 1'b0;
          result    <= 128'd0;
          top_valid <= 16'd0;
          for (i = 0; i < 16; i++) begin
            top_val[i] <= '0;
          end
          idx <= 5'd0; // start from element 0 in PROC
        end

        PROC: begin
          done <= 1'b0;

          if (idx < 5'd16) begin
            curr = elem[idx[3:0]]; // index 0..15

            // Insertion into sorted top list (descending)
            // Only maintain up to n_eff entries
            if (n_eff != 0) begin
              // Determine position to insert
              integer pos;
              integer limit;
              limit = (n_eff < 5'd16) ? n_eff : 5'd16;
              if (limit == 0)
                pos = 0;
              else begin
                pos = limit; // default: insert at end if smaller
                for (i = 0; i < limit; i++) begin
                  if (!top_valid[i]) begin
                    pos = i;
                    break;
                  end else if (curr > top_val[i]) begin
                    pos = i;
                    break;
                  end
                end
              end

              // Perform insert if within range
              if (pos < limit) begin
                // Shift down from last valid (limit-1) to pos
                for (j = limit-1; j > pos; j--) begin
                  if (top_valid[j-1]) begin
                    top_val[j]   <= top_val[j-1];
                    top_valid[j] <= 1'b1;
                  end else begin
                    top_val[j]   <= top_val[j];
                    top_valid[j] <= top_valid[j];
                  end
                end
                // Insert current element
                top_val[pos]   <= curr;
                top_valid[pos] <= 1'b1;
              end
            end

            idx <= idx + 5'd1;
          end
        end

        DONE: begin
          // Pack result from top_val in descending order, LSB-aligned
          done   <= 1'b1;

          result <= 128'd0;
          if (n_eff != 0) begin
            for (i = 0; i < 16; i++) begin
              if ((i < n_eff) && top_valid[i]) begin
                result[8*i +: 8] <= top_val[i];
              end else begin
                result[8*i +: 8] <= 8'd0;
              end
            end
          end
        end

        default: begin
          done   <= 1'b0;
          result <= 128'd0;
        end
      endcase
    end
  end

endmodule