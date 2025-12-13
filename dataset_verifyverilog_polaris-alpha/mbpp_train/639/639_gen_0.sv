module name_length_sum(
  input              clk,
  input              rst_n,
  input              start,
  input      [7:0]   name1 [0:7],
  input      [7:0]   name2 [0:7],
  input      [7:0]   name3 [0:7],
  input      [7:0]   name4 [0:7],
  output reg [5:0]   total_length,
  output reg         done
);

  // Internal registers
  reg [1:0]  name_idx;       // which name (0..3)
  reg [2:0]  char_idx;       // which char (0..7)
  reg        active;         // processing in progress
  reg        valid_name;     // current name is valid (uppercase first char)
  reg [5:0]  partial_sum;    // running total

  // Function to get character from selected name
  function automatic [7:0] get_char(
    input [1:0] idx,
    input [2:0] cidx
  );
    case (idx)
      2'd0: get_char = name1[cidx];
      2'd1: get_char = name2[cidx];
      2'd2: get_char = name3[cidx];
      2'd3: get_char = name4[cidx];
      default: get_char = 8'h00;
    endcase
  endfunction

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      total_length <= 6'd0;
      done         <= 1'b0;
      active       <= 1'b0;
      name_idx     <= 2'd0;
      char_idx     <= 3'd0;
      valid_name   <= 1'b0;
      partial_sum  <= 6'd0;
    end else begin
      done <= 1'b0; // default

      // Start processing on start assertion (only when not already active)
      if (start && !active) begin
        active      <= 1'b1;
        name_idx    <= 2'd0;
        char_idx    <= 3'd0;
        partial_sum <= 6'd0;
        valid_name  <= 1'b0;
      end

      if (active) begin
        // Per-cycle: process one name fully (length computation within cycle)
        reg [5:0] name_len;
        reg [7:0] c0;
        reg [7:0] c1;
        reg [7:0] c2;
        reg [7:0] c3;
        reg [7:0] c4;
        reg [7:0] c5;
        reg [7:0] c6;
        reg [7:0] c7;

        // Fetch all chars for current name combinationally
        c0 = get_char(name_idx, 3'd0);
        c1 = get_char(name_idx, 3'd1);
        c2 = get_char(name_idx, 3'd2);
        c3 = get_char(name_idx, 3'd3);
        c4 = get_char(name_idx, 3'd4);
        c5 = get_char(name_idx, 3'd5);
        c6 = get_char(name_idx, 3'd6);
        c7 = get_char(name_idx, 3'd7);

        // Check if first character is uppercase A-Z
        if (c0 >= 8'h41 && c0 <= 8'h5A) begin
          valid_name = 1'b1;
          // Compute length until null or 8 chars
          if (c0 == 8'h00)      name_len = 6'd0;
          else if (c1 == 8'h00) name_len = 6'd1;
          else if (c2 == 8'h00) name_len = 6'd2;
          else if (c3 == 8'h00) name_len = 6'd3;
          else if (c4 == 8'h00) name_len = 6'd4;
          else if (c5 == 8'h00) name_len = 6'd5;
          else if (c6 == 8'h00) name_len = 6'd6;
          else if (c7 == 8'h00) name_len = 6'd7;
          else                  name_len = 6'd8;
        end else begin
          valid_name = 1'b0;
          name_len   = 6'd0;
        end

        // Accumulate if valid
        if (valid_name) begin
          partial_sum <= partial_sum + name_len;
        end

        // Advance to next name (one name per cycle)
        if (name_idx == 2'd3) begin
          // Last name processed: finish
          total_length <= partial_sum + (valid_name ? name_len : 6'd0) - partial_sum; // adjusted below
        end

        // Recompute total_length correctly at the end of 4th name
        if (name_idx == 2'd3) begin
          total_length <= partial_sum + (valid_name ? name_len : 6'd0);
          done         <= 1'b1;
          active       <= 1'b0;
        end else begin
          name_idx <= name_idx + 2'd1;
        end
      end
    end
  end

endmodule