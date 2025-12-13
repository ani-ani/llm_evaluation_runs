module string_prefixer(
  input  clk,
  input  rst_n,
  input  start,
  input  [63:0] str,
  input  [2:0]  len,
  output reg [63:0] prefix,
  output reg [2:0]  plen,
  output reg        ready,
  output reg        done
);

  // Internal registers
  reg [63:0] str_reg;
  reg [2:0]  len_reg;
  reg [2:0]  idx;       // current prefix length counter (1..len_reg)
  reg        active;    // indicates processing in progress

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      str_reg <= 64'd0;
      len_reg <= 3'd0;
      idx     <= 3'd0;
      active  <= 1'b0;
      prefix  <= 64'd0;
      plen    <= 3'd0;
      ready   <= 1'b0;
      done    <= 1'b0;
    end else begin
      // Default outputs each cycle
      ready <= 1'b0;
      done  <= 1'b0;

      if (start && !active) begin
        // Start new operation: capture inputs
        str_reg <= str;
        len_reg <= len;

        if (len == 3'd0) begin
          // Zero-length string: no prefixes, done immediately
          prefix <= 64'd0;
          plen   <= 3'd0;
          ready  <= 1'b0;
          done   <= 1'b1;
          idx    <= 3'd0;
          active <= 1'b0;
        end else begin
          // Begin prefix generation; first prefix next cycle
          idx    <= 3'd1;
          active <= 1'b1;
        end

      end else if (active) begin
        // Emit current prefix for idx
        // Left-aligned: take top (idx * 8) bits of str_reg and align to MSBs
        // prefix[63:(64 - idx*8)] = str_reg[63:(64 - idx*8)]
        case (idx)
          3'd1: prefix <= {str_reg[63:56], 56'd0};
          3'd2: prefix <= {str_reg[63:48], 48'd0};
          3'd3: prefix <= {str_reg[63:40], 40'd0};
          3'd4: prefix <= {str_reg[63:32], 32'd0};
          3'd5: prefix <= {str_reg[63:24], 24'd0};
          3'd6: prefix <= {str_reg[63:16], 16'd0};
          3'd7: prefix <= {str_reg[63:8],   8'd0};
          default: prefix <= 64'd0;
        endcase

        plen  <= idx;
        ready <= 1'b1;

        if (idx == len_reg) begin
          // Last prefix: assert done and stop
          done   <= 1'b1;
          active <= 1'b0;
          idx    <= 3'd0;
        end else begin
          // Prepare for next prefix
          idx <= idx + 3'd1;
        end
      end
    end
  end

endmodule