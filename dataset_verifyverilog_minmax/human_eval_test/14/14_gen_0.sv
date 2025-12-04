module string_prefixer (
  input  clk,
  input  rst_n,
  input  start,
  input  [63:0] str, // packed representation of 8-byte string
  input  [2:0] len,
  output reg [63:0] prefix,
  output reg [2:0] plen,
  output reg ready,
  output reg done
);

  // Internal state
  typedef enum int unsigned { ST_IDLE = 0, ST_RUN = 1 } state_t;
  state_t state;
  reg [2:0] L;      // captured length (0..7)
  reg [63:0] S;     // captured string (packed)
  reg [2:0] idx;    // current prefix length being emitted (0..L-1)

  // Default outputs to avoid implicit latches
  always_comb begin
    ready  = 1'b0;
    done   = 1'b0;
    prefix = 64'b0;
    plen   = 3'b0;
    case (state)
      ST_IDLE: begin
        ready  = 1'b0;
        done   = (L == 3'b0); // zero-length string: done immediately
        prefix = 64'b0;
        plen   = 3'b0;
      end
      ST_RUN: begin
        // When idx == 0..(L-1) we are emitting a prefix
        if (idx < L) begin
          ready  = 1'b1;
          done   = (idx == (L - 1)); // done pulses with the last prefix
          prefix = S >> ((L - idx) * 8); // left-aligned prefix
          plen   = idx + 1;              // current prefix length (1..L)
        end else begin
          // No output after all prefixes have been emitted (should be short-lived)
          ready  = 1'b0;
          done   = 1'b1;
          prefix = 64'b0;
          plen   = 3'b0;
        end
      end
      default: begin
        ready  = 1'b0;
        done   = 1'b0;
        prefix = 64'b0;
        plen   = 3'b0;
      end
    endcase
  end

  // State and index updates
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      L     <= 3'b0;
      S     <= 64'b0;
      idx   <= 3'b0;
    end else begin
      case (state)
        ST_IDLE: begin
          idx <= 3'b0;
          if (start) begin
            L   <= len; // capture inputs on start
            S   <= str; // capture inputs on start
            state <= ST_RUN;
          end
        end
        ST_RUN: begin
          if (idx < L) begin
            idx <= idx + 1; // advance to next prefix
          end else begin
            // Completed all prefixes; return to idle
            state <= ST_IDLE;
            idx   <= 3'b0;
            L     <= 3'b0;
            S     <= 64'b0;
          end
        end
        default: state <= ST_IDLE;
      endcase
    end
  end
endmodule
