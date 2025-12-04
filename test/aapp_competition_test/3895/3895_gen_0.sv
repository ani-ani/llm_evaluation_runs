module function_decomposition(
  input clk,
  input rst_n,
  input start,
  input [2:0] f [0:7],
  output reg [2:3] m,
  output reg [2:3] g [0:7],
  output reg [2:3] h [0:7],
  output reg valid_out
);

  // State encoding for 5-cycle operation
  typedef enum logic [2:3] {
    S_IDLE   = 3'd0,
    S_CHECK1 = 3'd1,
    S_CHECK2 = 3'd2,
    S_BUILD  = 3'd3,
    S_OUT    = 3'd4
  } state_t;

  state_t state, next_state;

  reg invalid;
  reg [2:3] fixed_pts [0:7];
  reg [2:3] fixed_count;

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      m           <= 3'd0;
      valid_out   <= 1'b0;
      fixed_count <= 3'd0;
      invalid     <= 1'b0;
      g[0]        <= 3'd0; g[1] <= 3'd0; g[2] <= 3'd0; g[3] <= 3'd0;
      g[4]        <= 3'd0; g[5] <= 3'd0; g[6] <= 3'd0; g[7] <= 3'd0;
      h[0]        <= 3'd0; h[1] <= 3'd0; h[2] <= 3'd0; h[3] <= 3'd0;
      h[4]        <= 3'd0; h[5] <= 3'd0; h[6] <= 3'd0; h[7] <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          valid_out   <= 1'b0;
          fixed_count <= 3'd0;
          invalid     <= 1'b0;
        end

        S_CHECK1: begin
          // Check involution: f[f[i]] == f[i] for all i
          // Early set invalid if any violation
          if (!invalid) begin
            if (f[f[0]] != f[0]) invalid <= 1'b1;
            if (f[f[1]] != f[1]) invalid <= 1'b1;
            if (f[f[2]] != f[2]) invalid <= 1'b1;
            if (f[f[3]] != f[3]) invalid <= 1'b1;
            if (f[f[4]] != f[4]) invalid <= 1'b1;
            if (f[f[5]] != f[5]) invalid <= 1'b1;
            if (f[f[6]] != f[6]) invalid <= 1'b1;
            if (f[f[7]] != f[7]) invalid <= 1'b1;
          end
        end

        S_CHECK2: begin
          // Collect unique fixed points f[i]==i
          if (!invalid) begin
            integer i, j;
            reg unique_fp;
            for (i = 0; i < 8; i = i + 1) begin
              if (f[i] == i[2:3]) begin
                unique_fp = 1'b1;
                for (j = 0; j < fixed_count; j = j + 1) begin
                  if (fixed_pts[j] == i[2:3]) begin
                    unique_fp = 1'b0;
                  end
                end
                if (unique_fp) begin
                  fixed_pts[fixed_count] <= i[2:3];
                  fixed_count           <= fixed_count + 3'd1;
                end
              end
            end

            // If no fixed points, treat as invalid
            if (fixed_count == 3'd0) begin
              invalid <= 1'b1;
            end
          end
        end

        S_BUILD: begin
          integer i, j;
          // If invalid, clear outputs; else build h and g
          if (invalid) begin
            m         <= 3'd0;
            valid_out <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
              g[i] <= 3'd0;
              h[i] <= 3'd0;
            end
          end else begin
            // Build h from collected fixed points (pad remaining with 0)
            for (i = 0; i < 8; i = i + 1) begin
              if (i < fixed_count)
                h[i] <= fixed_pts[i];
              else
                h[i] <= 3'd0;
            end

            // Set m as number of fixed points (1..8)
            m <= fixed_count;

            // For each i, g[i] = index of f[i] in h + 1 (1-based index)
            for (i = 0; i < 8; i = i + 1) begin
              g[i] <= 3'd0;
              for (j = 0; j < fixed_count; j = j + 1) begin
                if (f[i] == h[j]) begin
                  g[i] <= j[2:3] + 3'd1;
                end
              end
            end
          end
        end

        S_OUT: begin
          // Outputs are already built in S_BUILD
          valid_out <= (invalid) ? 1'b0 : 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_CHECK1;
      end
      S_CHECK1: begin
        next_state = S_CHECK2; // cycle 2
      end
      S_CHECK2: begin
        next_state = S_BUILD;  // cycle 3
      end
      S_BUILD: begin
        next_state = S_OUT;    // cycle 4
      end
      S_OUT: begin
        // result valid in this state (cycle 5 after start)
        next_state = S_IDLE;
      end
      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule