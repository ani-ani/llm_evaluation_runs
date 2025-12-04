module space_replacer (
  input clk,
  input rst_n,
  input start,
  input [127:0] in_str,
  output reg done,
  output reg [383:0] out_str
);

  typedef enum logic [1:0] { IDLE = 2'b00, PROCESSING = 2'b01, DONE = 2'b10 } state_t;

  state_t state, next_state;

  logic [3:0] in_cnt;   // 0..15
  logic [5:0] out_ptr;  // 0..47
  logic [7:0] byte_val;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Output and counters
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_str <= '0;
      done <= 1'b0;
      in_cnt <= 4'd0;
      out_ptr <= 6'd0;
    end else begin
      done <= 1'b0; // default; overridden in DONE state

      case (state)
        IDLE: begin
          out_str <= '0;
          in_cnt <= 4'd0;
          out_ptr <= 6'd0;
          if (start) begin
            // Will read in_cnt=0 in PROCESSING next cycle
            next_state <= PROCESSING;
          end else begin
            next_state <= IDLE;
          end
        end

        PROCESSING: begin
          // Byte to process: LSB-first order (in_str[7:0] is first character)
          byte_val = in_str[8 * in_cnt +: 8];

          if (byte_val == 8'h20) begin
            // Write '%' (0x25), '2' (0x32), '0' (0x30)
            out_str[8 * out_ptr +: 8] <= 8'h25; // '%'
            out_str[8 * (out_ptr + 1) +: 8] <= 8'h32; // '2'
            out_str[8 * (out_ptr + 2) +: 8] <= 8'h30; // '0'
            out_ptr <= out_ptr + 3;
          end else begin
            out_str[8 * out_ptr +: 8] <= byte_val;
            out_ptr <= out_ptr + 1;
          end

          if (in_cnt == 4'd15) begin
            next_state <= DONE;
          end else begin
            in_cnt <= in_cnt + 1;
            next_state <= PROCESSING;
          end
        end

        DONE: begin
          done <= 1'b1;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase
    end
  end

  // Combinational next-state mux to avoid latches
  always_comb begin
    if (state == IDLE) begin
      if (start) next_state = PROCESSING;
      else next_state = IDLE;
    end else if (state == PROCESSING) begin
      if (in_cnt == 4'd15) next_state = DONE;
      else next_state = PROCESSING;
    end else begin // DONE
      next_state = IDLE;
    end
  end

endmodule