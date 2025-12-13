module reverse_pair_counter(
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0][7:0] strings [7:0],
  input  [2:0] n_strings,
  output reg [4:0] count,
  output reg       done
);

  // State encoding
  localparam IDLE      = 2'b00;
  localparam COMPARING = 2'b01;
  localparam DONE      = 2'b10;

  reg [1:0] state, next_state;
  reg [2:0] i, j;               // indices for string pairs

  // Latched inputs at start
  reg [7:0][7:0] strings_latched [7:0];
  reg [2:0]      n_strings_latched;

  // Reversed string of strings_latched[i]
  reg [7:0][7:0] rev_i;

  // Equality detection
  wire equal;
  assign equal = (rev_i[0] == strings_latched[j][0]) &&
                 (rev_i[1] == strings_latched[j][1]) &&
                 (rev_i[2] == strings_latched[j][2]) &&
                 (rev_i[3] == strings_latched[j][3]) &&
                 (rev_i[4] == strings_latched[j][4]) &&
                 (rev_i[5] == strings_latched[j][5]) &&
                 (rev_i[6] == strings_latched[j][6]) &&
                 (rev_i[7] == strings_latched[j][7]);

  // Sequential state, counters, and latching logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state               <= IDLE;
      i                   <= 3'd0;
      j                   <= 3'd0;
      count               <= 5'd0;
      done                <= 1'b0;
      n_strings_latched   <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done  <= 1'b0;
          count <= 5'd0;
          if (start) begin
            // Latch inputs
            strings_latched[0] <= strings[0];
            strings_latched[1] <= strings[1];
            strings_latched[2] <= strings[2];
            strings_latched[3] <= strings[3];
            strings_latched[4] <= strings[4];
            strings_latched[5] <= strings[5];
            strings_latched[6] <= strings[6];
            strings_latched[7] <= strings[7];
            n_strings_latched  <= n_strings;

            i <= 3'd0;
            j <= 3'd1;
          end
        end

        COMPARING: begin
          // Update reversed version of current i string
          rev_i[0] <= strings_latched[i][7];
          rev_i[1] <= strings_latched[i][6];
          rev_i[2] <= strings_latched[i][5];
          rev_i[3] <= strings_latched[i][4];
          rev_i[4] <= strings_latched[i][3];
          rev_i[5] <= strings_latched[i][2];
          rev_i[6] <= strings_latched[i][1];
          rev_i[7] <= strings_latched[i][0];

          // Count match for current pair (i,j)
          if (equal)
            count <= count + 5'd1;

          // Advance pair indices
          if (j + 3'd1 < n_strings_latched) begin
            j <= j + 3'd1;
          end else begin
            if (i + 3'd2 < n_strings_latched) begin
              i <= i + 3'd1;
              j <= (i + 3'd1) + 3'd1; // next j = new i + 1
            end
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start && (n_strings != 3'd0)) begin
          next_state = COMPARING;
        end else if (start && (n_strings == 3'd0)) begin
          next_state = DONE;
        end
      end

      COMPARING: begin
        // When i reaches n_strings-2 and j reaches n_strings-1, we are done
        if ((i + 3'd2 >= n_strings_latched) && (j + 3'd1 >= n_strings_latched)) begin
          next_state = DONE;
        end else begin
          next_state = COMPARING;
        end
      end

      DONE: begin
        // Wait for start deassertion then new start
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule