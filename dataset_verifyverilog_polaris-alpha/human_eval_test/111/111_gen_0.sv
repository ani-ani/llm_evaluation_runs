module histogram(
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] char_in,
  input        last_char,
  output reg [25:0] max_letters,
  output reg [4:0]  max_count,
  output reg        done
);

  // 26 counters for 'a' to 'z', 5 bits each
  reg [4:0] cnt[25:0];
  reg [4:0] valid_count;          // counts number of valid letters processed (0-16)
  reg       last_char_d1;         // pipeline stage 1 of last_char
  reg       last_char_d2;         // pipeline stage 2 of last_char
  reg       computing_max;        // indicates we are in max computation/result phase

  integer i;

  // Helper wires
  wire is_lowercase;
  wire [4:0] idx;
  assign is_lowercase = (char_in >= 8'h61) && (char_in <= 8'h7A);
  assign idx = char_in[4:0] - 5'd1; // 'a'(97)->5'b00000 after subtract 1 (since 97[4:0]=1)

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      for (i = 0; i < 26; i = i + 1) begin
        cnt[i] <= 5'd0;
      end
      valid_count   <= 5'd0;
      max_letters   <= 26'd0;
      max_count     <= 5'd0;
      done          <= 1'b0;
      last_char_d1  <= 1'b0;
      last_char_d2  <= 1'b0;
      computing_max <= 1'b0;
    end else begin
      // Default assignments
      done <= 1'b0;

      // Pipeline last_char
      last_char_d1 <= last_char & start;
      last_char_d2 <= last_char_d1;

      // Start of new processing window: when start is low, clear state
      if (!start) begin
        for (i = 0; i < 26; i = i + 1) begin
          cnt[i] <= 5'd0;
        end
        valid_count   <= 5'd0;
        max_letters   <= 26'd0;
        max_count     <= 5'd0;
        computing_max <= 1'b0;
      end else begin
        // Counting phase (while not in computation phase)
        if (!computing_max) begin
          // Accept valid lowercase letters, up to 16 of them
          if (is_lowercase && (valid_count < 5'd16)) begin
            cnt[idx]      <= cnt[idx] + 5'd1;
            valid_count   <= valid_count + 5'd1;
          end

          // Once last_char observed, enable computation pipeline
          if (last_char) begin
            computing_max <= 1'b1;
          end
        end

        // Two-cycle latency after last_char:
        // - Cycle (last_char_d1): no output yet
        // - Cycle (last_char_d2): compute max and assert done
        if (computing_max && last_char_d2) begin
          // Find maximum count
          reg [4:0] local_max;
          reg [25:0] local_mask;
          local_max  = 5'd0;
          local_mask = 26'd0;

          // First pass: find max value
          for (i = 0; i < 26; i = i + 1) begin
            if (cnt[i] > local_max)
              local_max = cnt[i];
          end

          // Second pass: build mask of letters with max count
          if (local_max != 5'd0) begin
            for (i = 0; i < 26; i = i + 1) begin
              if (cnt[i] == local_max)
                local_mask[i] = 1'b1;
              else
                local_mask[i] = 1'b0;
            end
          end else begin
            local_mask = 26'd0;
          end

          max_count   <= local_max;
          max_letters <= local_mask;
          done        <= 1'b1;   // Assert done for one cycle

          // Stay in computing_max until start is deasserted (cleared above)
        end
      end
    end
  end

endmodule