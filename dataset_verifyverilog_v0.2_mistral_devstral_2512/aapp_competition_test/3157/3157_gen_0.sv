module hash_word_counter (
  input clk,
  input rst_n,
  input start,
  input [4:0] N,
  input [24:0] K,
  input [4:0] M,
  output reg [31:0] result,
  output reg done
);

  // Define states
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] INIT = 2'b01;
  localparam [1:0] PROCESSING = 2'b10;
  localparam [1:0] DONE = 2'b11;

  reg [1:0] state;
  reg [4:0] step;
  reg [11:0] h_addr;
  reg [4:0] c;
  reg [31:0] temp_count;
  reg [24:0] new_hash;
  reg [31:0] dp_a [0:4095];
  reg [31:0] dp_b [0:4095];
  reg [31:0] dp_current [0:4095];
  reg [31:0] dp_next [0:4095];
  reg use_dp_a;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      step <= 0;
      h_addr <= 0;
      c <= 0;
      temp_count <= 0;
      new_hash <= 0;
      done <= 0;
      result <= 0;
      use_dp_a <= 1;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
          end
        end
        INIT: begin
          // Initialize DP table
          dp_a[0] <= 1;
          for (integer i = 1; i < 4096; i = i + 1) begin
            dp_a[i] <= 0;
          end
          state <= PROCESSING;
          step <= 1;
          h_addr <= 0;
          c <= 0;
          temp_count <= 0;
          new_hash <= 0;
        end
        PROCESSING: begin
          if (step < N) begin
            if (h_addr < 4096) begin
              if (c < 26) begin
                // Compute new hash
                new_hash <= ((h_addr * 33) ^ (c + 1)) % (1 << M);
                // Accumulate count
                temp_count <= temp_count + dp_current[h_addr];
                c <= c + 1;
              end else begin
                // Write accumulated count to next DP table
                dp_next[new_hash] <= temp_count;
                h_addr <= h_addr + 1;
                c <= 0;
                temp_count <= 0;
              end
            end else begin
              // Move to next step
              step <= step + 1;
              h_addr <= 0;
              c <= 0;
              temp_count <= 0;
              // Swap DP tables
              use_dp_a <= !use_dp_a;
            end
          end else begin
            state <= DONE;
            result <= dp_current[K];
            done <= 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

  // Assign current and next DP tables based on use_dp_a
  always @(*) begin
    if (use_dp_a) begin
      for (integer i = 0; i < 4096; i = i + 1) begin
        dp_current[i] = dp_a[i];
        dp_next[i] = dp_b[i];
      end
    end else begin
      for (integer i = 0; i < 4096; i = i + 1) begin
        dp_current[i] = dp_b[i];
        dp_next[i] = dp_a[i];
      end
    end
  end

endmodule