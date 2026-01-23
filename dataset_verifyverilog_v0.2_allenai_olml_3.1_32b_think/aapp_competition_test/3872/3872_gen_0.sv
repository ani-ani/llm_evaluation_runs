module string_equivalence(input clk, input rst_n, input start, input [127:0] string_a, input [127:0] string_b, output reg equivalent, output reg done);

// Internal registers
reg [7:0] a_char [15:0];
reg [7:0] b_char [15:0];
reg [2:0] state, next_state;
reg [2:0] block_size;
reg [2:0] chunk_idx;

// State definitions
parameter IDLE = 3'd0, INIT = 3'd1, PROCESS = 3'd2, NEXT_PASS = 3'd3, COMPARE = 3'd4, DONE = 3'd5;

// Default assignments
always @(*) begin
  state <= IDLE;
  next_state <= IDLE;
  block_size <= 3'd1;
  chunk_idx <= 3'd0;
  equivalent <= 1'b0;
  done <= 1'b0;

  // Load string_a into a_char
  a_char[0] = string_a[7:0];
  a_char[1] = string_a[15:8];
  a_char[2] = string_a[23:16];
  a_char[3] = string_a[31:24];
  a_char[4] = string_a[39:32];
  a_char[5] = string_a[47:40];
  a_char[6] = string_a[55:48];
  a_char[7] = string_a[63:56];
  a_char[8] = string_a[71:64];
  a_char[9] = string_a[79:72];
  a_char[10] = string_a[87:80];
  a_char[11] = string_a[95:88];
  a_char[12] = string_a[103:96];
  a_char[13] = string_a[111:104];
  a_char[14] = string_a[119:112];
  a_char[15] = string_a[127:120];

  // Load string_b into b_char
  b_char[0] = string_b[7:0];
  b_char[1] = string_b[15:8];
  b_char[2] = string_b[23:16];
  b_char[3] = string_b[31:24];
  b_char[4] = string_b[39:32];
  b_char[5] = string_b[47:40];
  b_char[6] = string_b[55:48];
  b_char[7] = string_b[63:56];
  b_char[8] = string_b[71:64];
  b_char[9] = string_b[79:72];
  b_char[10] = string_b[87:80];
  b_char[11] = string_b[95:88];
  b_char[12] = string_b[103:96];
  b_char[13] = string_b[111:104];
  b_char[14] = string_b[119:112];
  b_char[15] = string_b[127:120];
end

// State machine
always @(posedge clk) begin
  if (!rst_n) begin
    state <= IDLE;
    next_state <= IDLE;
    block_size <= 3'd1;
    chunk_idx <= 3'd0;
    equivalent <= 1'b0;
    done <= 1'b0;
  end else begin
    case (state)
      IDLE: begin
        if (start) next_state <= INIT;
        else next_state <= IDLE;
        equivalent <= 1'b0;
        done <= 1'b0;
      end

      INIT: begin
        next_state <= PROCESS;
        equivalent <= 1'b0;
        done <= 1'b0;
      end

      PROCESS: begin
        integer i_val;
        integer total_chunks;
        case (block_size)
          1: i_val = chunk_idx * 2; total_chunks = 8; break;
          2: i_val = chunk_idx * 4; total_chunks = 4; break;
          4: i_val = chunk_idx * 8; total_chunks = 2; break;
          8: i_val = 0; total_chunks = 1; break;
        endcase

        if (chunk_idx < total_chunks) begin
          wire need_swap_a, need_swap_b;
          if (block_size == 1) begin
            need_swap_a = a_char[i_val] > a_char[i_val + 1];
            need_swap_b = b_char[i_val] > b_char[i_val + 1];
          end else if (block_size == 2) begin
            need_swap_a = 0;
            if (a_char[i_val] > a_char[i_val + 2]) need_swap_a = 1;
            else if (a_char[i_val] < a_char[i_val + 2]) need_swap_a = 0;
            else begin
              if (a_char[i_val + 1] > a_char[i_val + 3]) need_swap_a = 1;
              else if (a_char[i_val + 1] < a_char[i_val + 3]) need_swap_a = 0;
              else need_swap_a = 0;
            end
            need_swap_b = 0;
            if (b_char[i_val] > b_char[i_val + 2]) need_swap_b = 1;
            else if (b_char[i_val] < b_char[i_val + 2]) need_swap_b = 0;
            else begin
              if (b_char[i_val + 1] > b_char[i_val + 3]) need_swap_b = 1;
              else if (b_char[i_val + 1] < b_char[i_val + 3]) need_swap_b = 0;
              else need_swap_b = 0;
            end
          end

          // Swap logic for block_size == 1
          if (block_size == 1) begin
            if (need_swap_a) begin
              temp = a_char[i_val];
              a_char[i_val] = a_char[i_val + 1];
              a_char[i_val + 1] = temp;
            end
            if (need_swap_b) begin
              temp = b_char[i_val];
              b_char[i_val] = b_char[i_val + 1];
              b_char[i_val + 1] = temp;
            end;
          end

          if (chunk_idx < total_chunks - 1) begin
            chunk_idx <= chunk_idx + 1;
          end else begin
            next_state <= NEXT_PASS;
            chunk_idx <= 3'd0;
          end
        end else begin
          next_state <= NEXT_PASS;
          chunk_idx <= 3'd0;
        end

        equivalent <= 1'b0;
        done <= 1'b0;
      end

      NEXT_PASS: begin
        if (block_size == 8) begin
          next_state <= COMPARE;
        end else begin
          if (block_size == 1) block_size <= 2;
          else if (block_size == 2) block_size <= 4;
          else if (block_size == 4) block_size <= 8;
          next_state <= PROCESS;
        end
        chunk_idx <= 3'd0;
        equivalent <= 1'b0;
        done <= 1'b0;
      end

      COMPARE: begin
        equivalent = 1'b1;
        for (int i=0; i<16; i++) begin
          if (a_char[i] !== b_char[i]) equivalent = 1'b0;
        end
        next_state <= DONE;
        equivalent = equivalent;
      end

      DONE: begin
        done <= 1'b1;
        next_state <= IDLE;
      end

      default: next_state <= IDLE;
    endcase
    state <= next_state;
  end
endmodule