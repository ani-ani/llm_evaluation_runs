module color_code_verifier(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start verification
  input [3:0] n, // number of bits (support up to 4)
  input [3:0] p, // palette size (1-4) - not used directly, palette bitmask drives checks
  input [15:0] palette, // bitmask where palette[i-1]=1 means i is in P
  input [15:0][3:0] sequence_in, // 16 elements of 4-bit values
  output reg valid, // 1 if valid color code, 0 if invalid
  output reg done // asserted when verification complete
);

  // internal state
  reg [4:0] idx;            // supports up to 15
  reg [4:0] max_idx;        // last index to check (2^n - 2), max 14
  reg running;              // indicates verification in progress

  // compute popcount of 4-bit value for Hamming distance
  function automatic [2:0] popcount4(input [3:0] v);
    begin
      popcount4 = v[0] + v[1] + v[2] + v[3];
    end
  endfunction

  // main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid   <= 1'b0;
      done    <= 1'b0;
      idx     <= 5'd0;
      max_idx <= 5'd0;
      running <= 1'b0;
    end else begin
      if (start && !running) begin
        // initialize verification
        valid   <= 1'b1;                        // assume valid until proven otherwise
        done    <= 1'b0;
        running <= 1'b1;
        idx     <= 5'd0;

        // compute (2^n) - 2 safely for n in [0..4]; only meaningful for n>=1
        if (n == 4'd0) begin
          max_idx <= 5'd0;                      // no transitions; treat as trivially valid
        end else begin
          max_idx <= ((5'd1 << n) - 5'd2);
        end
      end else if (running && !done) begin
        if (n == 4'd0) begin
          // no transitions to check; complete immediately
          done    <= 1'b1;
          running <= 1'b0;
        end else begin
          // check current transition idx -> idx+1 if within range
          if (idx <= max_idx) begin
            // XOR to get differing bits, then popcount
            reg [3:0] diff;
            reg [2:0] dist;
            diff = sequence_in[idx] ^ sequence_in[idx + 1];
            dist = popcount4(diff);

            // valid distance must be in [1..4] and enabled in palette bitmask
            if (dist == 3'd0 || dist > 3'd4 || !palette[dist-1]) begin
              valid   <= 1'b0;
              done    <= 1'b1;
              running <= 1'b0;
            end else begin
              // move to next index or finish if this was the last
              if (idx == max_idx) begin
                // all checked and valid
                valid   <= 1'b1;
                done    <= 1'b1;
                running <= 1'b0;
              end else begin
                idx <= idx + 5'd1;
              end
            end
          end else begin
            // safety: if idx somehow exceeded, end verification
            done    <= 1'b1;
            running <= 1'b0;
          end
        end
      end
      // if not running and start not asserted, hold current outputs
    end
  end

endmodule