module book_circle (
  input clk,
  input rst_n,
  input start,
  input [3:0] boy_count,
  input [3:0] girl_count,
  input [7:0][7:0] adj_matrix,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  localparam [3:0] IDLE = 0;
  localparam [3:0] INIT = 1;
  localparam [3:0] PROCESS_BOY = 2;
  localparam [3:0] PROCESS_MASK = 3;
  localparam [3:0] CHECK_GIRL = 4;
  localparam [3:0] UPDATE = 5;
  localparam [3:0] NEXT_MASK = 6;
  localparam [3:0] COPY_DP = 7;
  localparam [3:0] NEXT_BOY = 8;
  localparam [3:0] DONE = 9;

  // State register
  reg [3:0] state = IDLE;

  // DP arrays (256 entries x 4 bits)
  reg [3:0] dp_curr [0:255];
  reg [3:0] dp_next [0:255];

  // Counters
  reg [3:0] boy_idx = 0;
  reg [7:0] mask = 0;
  reg [3:0] girl_idx = 0;
  reg [3:0] best = 0;
  reg [3:0] temp_mask = 0;
  reg [3:0] copy_idx = 0;

  // Control signals
  reg mask_done = 0;
  reg girl_done = 0;
  reg copy_done = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      boy_idx <= 0;
      mask <= 0;
      girl_idx <= 0;
      best <= 0;
      temp_mask <= 0;
      copy_idx <= 0;
      mask_done <= 0;
      girl_done <= 0;
      copy_done <= 0;
      done <= 0;
      result <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            done <= 0;
          end
        end

        INIT: begin
          // Initialize dp_curr to 0
          for (integer i = 0; i < 256; i = i + 1) begin
            dp_curr[i] <= 0;
          end
          state <= PROCESS_BOY;
          boy_idx <= 0;
        end

        PROCESS_BOY: begin
          if (boy_idx == boy_count) begin
            state <= DONE;
          end else begin
            mask <= 0;
            state <= PROCESS_MASK;
          end
        end

        PROCESS_MASK: begin
          if (mask == (1 << girl_count) - 1) begin
            mask_done <= 1;
            state <= COPY_DP;
          end else begin
            best <= dp_curr[mask];
            girl_idx <= 0;
            state <= CHECK_GIRL;
          end
        end

        CHECK_GIRL: begin
          if (girl_idx == girl_count) begin
            dp_next[mask] <= best;
            mask <= mask + 1;
            state <= PROCESS_MASK;
          end else if (mask[girl_idx]) begin
            temp_mask <= mask ^ (1 << girl_idx);
            if (adj_matrix[boy_idx][girl_idx]) begin
              if (dp_curr[temp_mask] + 1 > best) begin
                best <= dp_curr[temp_mask] + 1;
              end
            end
            girl_idx <= girl_idx + 1;
          end else begin
            girl_idx <= girl_idx + 1;
          end
        end

        COPY_DP: begin
          if (copy_idx == (1 << girl_count) - 1) begin
            copy_done <= 1;
            state <= NEXT_BOY;
          end else begin
            dp_curr[copy_idx] <= dp_next[copy_idx];
            copy_idx <= copy_idx + 1;
          end
        end

        NEXT_BOY: begin
          boy_idx <= boy_idx + 1;
          copy_idx <= 0;
          copy_done <= 0;
          state <= PROCESS_BOY;
        end

        DONE: begin
          result <= dp_curr[(1 << girl_count) - 1];
          done <= 1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule