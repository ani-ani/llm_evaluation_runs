module wiring_possibilities(
  input clk,
  input rst_n,
  input start,
  input [1:0] m,
  input [3:0] photo1_sw,
  input [3:0] photo1_lgt,
  input [3:0] photo2_sw,
  input [3:0] photo2_lgt,
  output reg [19:0] result,
  output reg done
);

  // permutation index 0..23
  reg [4:0] perm_idx;

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_LOAD   = 3'd2,
    S_CHECK1 = 3'd3,
    S_CHECK2 = 3'd4,
    S_NEXT   = 3'd5,
    S_DONE   = 3'd6
  } state_t;

  state_t state, next_state;

  // store current mapping (function of permutation)
  reg [1:0] map0, map1, map2, map3; // light index for switch 0..3

  // counters and flags
  reg [4:0] valid_count; // 0..24 fits in 5 bits
  reg perm_valid;

  // photo mismatch signals
  reg mismatch1;
  reg mismatch2;

  // combinational: generate mapping based on perm_idx
  always @* begin
    // default assignment (not used, but for completeness)
    map0 = 2'd0;
    map1 = 2'd1;
    map2 = 2'd2;
    map3 = 2'd3;

    case (perm_idx)
      5'd0:  begin map0=0; map1=1; map2=2; map3=3; end
      5'd1:  begin map0=0; map1=1; map2=3; map3=2; end
      5'd2:  begin map0=0; map1=2; map2=1; map3=3; end
      5'd3:  begin map0=0; map1=2; map2=3; map3=1; end
      5'd4:  begin map0=0; map1=3; map2=1; map3=2; end
      5'd5:  begin map0=0; map1=3; map2=2; map3=1; end
      5'd6:  begin map0=1; map1=0; map2=2; map3=3; end
      5'd7:  begin map0=1; map1=0; map2=3; map3=2; end
      5'd8:  begin map0=1; map1=2; map2=0; map3=3; end
      5'd9:  begin map0=1; map1=2; map2=3; map3=0; end
      5'd10: begin map0=1; map1=3; map2=0; map3=2; end
      5'd11: begin map0=1; map1=3; map2=2; map3=0; end
      5'd12: begin map0=2; map1=0; map2=1; map3=3; end
      5'd13: begin map0=2; map1=0; map2=3; map3=1; end
      5'd14: begin map0=2; map1=1; map2=0; map3=3; end
      5'd15: begin map0=2; map1=1; map2=3; map3=0; end
      5'd16: begin map0=2; map1=3; map2=0; map3=1; end
      5'd17: begin map0=2; map1=3; map2=1; map3=0; end
      5'd18: begin map0=3; map1=0; map2=1; map3=2; end
      5'd19: begin map0=3; map1=0; map2=2; map3=1; end
      5'd20: begin map0=3; map1=1; map2=0; map3=2; end
      5'd21: begin map0=3; map1=1; map2=2; map3=0; end
      5'd22: begin map0=3; map1=2; map2=0; map3=1; end
      5'd23: begin map0=3; map1=2; map2=1; map3=0; end
      default: begin map0=0; map1=1; map2=2; map3=3; end
    endcase
  end

  // combinational: next state logic
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_LOAD;
      end
      S_LOAD: begin
        next_state = S_CHECK1;
      end
      S_CHECK1: begin
        if (m == 2'd0)
          next_state = S_NEXT;
        else if (m == 2'd1)
          next_state = S_NEXT;
        else
          next_state = S_CHECK2;
      end
      S_CHECK2: begin
        next_state = S_NEXT;
      end
      S_NEXT: begin
        if (perm_idx == 5'd23)
          next_state = S_DONE;
        else
          next_state = S_LOAD;
      end
      S_DONE: begin
        // done is asserted for 1 cycle, then go back to IDLE
        next_state = S_IDLE;
      end
      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // combinational: check logic for photos
  always @* begin
    // default no mismatch
    mismatch1 = 1'b0;
    mismatch2 = 1'b0;

    // Photo 1 check if used (m >= 1)
    if (m >= 2'd1) begin
      if (photo1_sw[0] != photo1_lgt[map0]) mismatch1 = 1'b1;
      if (photo1_sw[1] != photo1_lgt[map1]) mismatch1 = 1'b1;
      if (photo1_sw[2] != photo1_lgt[map2]) mismatch1 = 1'b1;
      if (photo1_sw[3] != photo1_lgt[map3]) mismatch1 = 1'b1;
    end

    // Photo 2 check if used (m == 2)
    if (m == 2'd2) begin
      if (photo2_sw[0] != photo2_lgt[map0]) mismatch2 = 1'b1;
      if (photo2_sw[1] != photo2_lgt[map1]) mismatch2 = 1'b1;
      if (photo2_sw[2] != photo2_lgt[map2]) mismatch2 = 1'b1;
      if (photo2_sw[3] != photo2_lgt[map3]) mismatch2 = 1'b1;
    end
  end

  // sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      perm_idx    <= 5'd0;
      valid_count <= 5'd0;
      result      <= 20'd0;
      done        <= 1'b0;
      perm_valid  <= 1'b0;
    end else begin
      state <= next_state;

      // default outputs each cycle
      done <= 1'b0;

      case (state)
        S_IDLE: begin
          perm_idx    <= 5'd0;
          valid_count <= 5'd0;
          perm_valid  <= 1'b0;
        end

        S_INIT: begin
          perm_idx    <= 5'd0;
          valid_count <= 5'd0;
          perm_valid  <= 1'b0;
        end

        S_LOAD: begin
          // mapping is combinational from perm_idx
          perm_valid <= 1'b1; // assume valid until a mismatch is found
        end

        S_CHECK1: begin
          if (m >= 2'd1 && mismatch1)
            perm_valid <= 1'b0;
        end

        S_CHECK2: begin
          if (m == 2'd2 && mismatch2)
            perm_valid <= 1'b0;
        end

        S_NEXT: begin
          if (perm_valid)
            valid_count <= valid_count + 5'd1;

          if (perm_idx != 5'd23) begin
            perm_idx   <= perm_idx + 5'd1;
            perm_valid <= 1'b0;
          end
        end

        S_DONE: begin
          // final result is valid_count mod 1000003 (valid_count <= 24, so direct assign)
          result <= {{15{1'b0}}, valid_count};
          done   <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

endmodule
